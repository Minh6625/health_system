from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import func, text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.adapters import ModelApiHealthAdapter, RiskPersistenceAdapter
from app.core.alert_constants import get_escalation_rule
from app.models.risk_score_model import RiskScore
from app.observability.timing import StageTimer
from app.repositories.emergency_repository import EmergencyRepository
from app.services.model_api_client import get_model_api_client
from app.services.notification_service import NotificationService
from app.services.push_notification_service import PushNotificationService
from app.services.risk_inference_service import (
    describe_feature_vector,
    infer_risk,
)
from app.utils.datetime_helper import get_current_time

logger = logging.getLogger(__name__)

RISK_COOLDOWN_SECONDS = int(os.getenv("RISK_COOLDOWN_SECONDS", "60"))
RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS = 60


@dataclass(frozen=True)
class RiskCalculationResult:
    risk_score_id: int
    score: float
    risk_level: str
    model: str
    calculated_at: datetime
    is_tentative: bool = False


def _derive_age(date_of_birth: date | None) -> float:
    if date_of_birth is None:
        return 35.0
    today = datetime.now(UTC).date()
    years = today.year - date_of_birth.year
    if (today.month, today.day) < (date_of_birth.month, date_of_birth.day):
        years -= 1
    return float(max(years, 0))


def _gender_value(value: str | None) -> str:
    normalized = (value or "").strip().lower()
    if normalized in {"male", "m", "man", "nam"}:
        return "male"
    if normalized in {"female", "f", "woman", "nu", "nữ"}:
        return "female"
    return "female"

def load_device_owner_context(db: Session, device_id: int) -> dict[str, Any]:
    row = db.execute(
        text(
            """
            SELECT
                d.id AS device_id,
                d.user_id,
                d.is_active,
                d.deleted_at,
                u.date_of_birth,
                u.gender,
                u.weight_kg,
                u.height_cm
            FROM devices AS d
            INNER JOIN users AS u
                ON u.id = d.user_id
            WHERE d.id = :device_id
            """
        ),
        {"device_id": device_id},
    ).mappings().first()

    if row is None or row.get("deleted_at") is not None or not row.get("is_active", True):
        raise ValueError(f"Device {device_id} not found or inactive")

    return dict(row)


def _fetch_latest_vitals(db: Session, device_id: int) -> dict[str, Any] | None:
    # Average the 5 most-recent samples (~5 s of data at 1 Hz) so that a
    # single noisy reading does not dominate the risk score.
    query_with_bp = text(
        """
        SELECT
            MAX(time)                    AS time,
            AVG(heart_rate)              AS heart_rate,
            AVG(spo2)                    AS spo2,
            AVG(temperature)             AS temperature,
            AVG(hrv)                     AS hrv,
            AVG(respiratory_rate)        AS respiratory_rate,
            AVG(blood_pressure_sys)      AS blood_pressure_sys,
            AVG(blood_pressure_dia)      AS blood_pressure_dia
        FROM (
            SELECT time, heart_rate, spo2, temperature, hrv,
                   respiratory_rate, blood_pressure_sys, blood_pressure_dia
            FROM vitals
            WHERE device_id = :device_id
            ORDER BY time DESC
            LIMIT 5
        ) AS recent
        """
    )
    query_without_bp = text(
        """
        SELECT
            MAX(time)                    AS time,
            AVG(heart_rate)              AS heart_rate,
            AVG(spo2)                    AS spo2,
            AVG(temperature)             AS temperature,
            AVG(hrv)                     AS hrv,
            AVG(respiratory_rate)        AS respiratory_rate,
            NULL                         AS blood_pressure_sys,
            NULL                         AS blood_pressure_dia
        FROM (
            SELECT time, heart_rate, spo2, temperature, hrv, respiratory_rate
            FROM vitals
            WHERE device_id = :device_id
            ORDER BY time DESC
            LIMIT 5
        ) AS recent
        """
    )

    try:
        row = db.execute(query_with_bp, {"device_id": device_id}).mappings().first()
    except ProgrammingError as error:
        db.rollback()
        message = str(error)
        if 'relation "vitals" does not exist' in message:
            return None
        if "blood_pressure_sys" in message or "blood_pressure_dia" in message:
            row = db.execute(query_without_bp, {"device_id": device_id}).mappings().first()
        else:
            raise

    if row is None:
        return None
    row_dict = dict(row)
    # HS-024 / XR-003: reject record khi cả HR + SpO2 + body_temp NULL
    # (input quality gate — không đủ data để inference có ý nghĩa).
    if (
        row_dict.get("heart_rate") is None
        and row_dict.get("spo2") is None
        and row_dict.get("temperature") is None
    ):
        return None
    return row_dict


def _build_inference_payload(
    vitals_row: dict[str, Any],
    context: dict[str, Any],
) -> tuple[dict[str, Any], list[str]]:
    defaults_applied: list[str] = []

    sys_bp = vitals_row.get("blood_pressure_sys")
    if sys_bp is None:
        sys_bp = 120.0
        defaults_applied.append("blood_pressure_sys")

    dia_bp = vitals_row.get("blood_pressure_dia")
    if dia_bp is None:
        dia_bp = 80.0
        defaults_applied.append("blood_pressure_dia")

    hrv = vitals_row.get("hrv")
    if hrv is None:
        hrv = 40.0
        defaults_applied.append("hrv")

    weight_kg = context.get("weight_kg")
    if weight_kg is None:
        weight_kg = 65.0
        defaults_applied.append("weight_kg")

    height_cm = context.get("height_cm")
    if height_cm is None:
        height_cm = 165.0
        defaults_applied.append("height_cm")

    inference_payload = {
        "heart_rate": float(vitals_row.get("heart_rate") or 75.0),
        "resp_rate": float(vitals_row.get("respiratory_rate") or 16.0),
        "body_temp": float(vitals_row.get("temperature") or 36.6),
        "spo2": float(vitals_row.get("spo2") or 98.0),
        "sys_bp": float(sys_bp),
        "dia_bp": float(dia_bp),
        "age": _derive_age(context.get("date_of_birth")),
        "gender": _gender_value(context.get("gender")),
        "weight_kg": float(weight_kg),
        "height_cm": float(height_cm),
        "hrv": float(hrv),
    }

    return inference_payload, defaults_applied


def _resolve_risk_alert_recipients(db: Session, patient_user_id: int) -> list[int]:
    """Patient + caregivers (with ``can_receive_alerts``) for a risk push fan-out.

    Wraps :func:`EmergencyRepository.get_alert_recipient_user_ids` defensively so
    a transient relationship-table error never blocks the patient from getting
    their own alert.
    """
    recipients: list[int] = [int(patient_user_id)]
    try:
        caregiver_ids = EmergencyRepository.get_alert_recipient_user_ids(db, patient_user_id)
    except Exception:  # noqa: BLE001 - never let caregiver lookup break risk pipeline
        logger.exception(
            "Failed to fan-out risk alert to caregivers for user %s; using patient-only",
            patient_user_id,
        )
        return recipients

    seen = {int(patient_user_id)}
    for caregiver_id in caregiver_ids or []:
        try:
            cid = int(caregiver_id)
        except (TypeError, ValueError):
            continue
        if cid in seen:
            continue
        seen.add(cid)
        recipients.append(cid)
    return recipients


def dispatch_risk_alerts(
    db: Session,
    *,
    device_id: int,
    user_id: int,
    risk_level: str,
    score: float,
    risk_score_id: int | None = None,
    post_fall: bool = False,
) -> bool:
    """Escalation -> cooldown check -> create alerts -> send push notifications."""
    rule = get_escalation_rule(risk_level)
    if rule is None:
        logger.info("Risk alert skipped: level=%s does not require alerting", risk_level)
        return False

    assert rule.alert_type is not None
    assert rule.severity is not None

    if not post_fall and NotificationService.is_risk_alert_in_cooldown(
        db,
        device_id=device_id,
        alert_type=rule.alert_type,
    ):
        logger.warning(
            "Risk alert suppressed by cooldown: device=%s type=%s level=%s window=%ss",
            device_id,
            rule.alert_type,
            risk_level,
            os.getenv("RISK_ALERT_COOLDOWN_SECONDS", "300"),
        )
        return False

    try:
        recipient_user_ids = _resolve_risk_alert_recipients(db, int(user_id))
        title = rule.title_template
        body = rule.message_template.format(score=score)
        alert_details: dict[str, Any] = {
            "device_id": device_id,
            "risk_level": risk_level,
            "escalation_stage": "initial",
            "auto_escalate_after_seconds": RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS,
        }
        if risk_score_id is not None:
            alert_details["risk_score_id"] = risk_score_id

        notification_id_by_user = NotificationService.create_risk_alerts(
            db,
            recipient_user_ids=recipient_user_ids,
            device_id=device_id,
            rule=rule,
            risk_score=score,
            risk_score_id=risk_score_id,
            details=alert_details,
        )

        PushNotificationService.send_risk_push_alerts(
            db,
            recipient_user_ids=recipient_user_ids,
            title=title,
            body=body,
            alert_type=rule.alert_type,
            risk_level=risk_level,
            device_id=device_id,
            notification_id_by_user=notification_id_by_user,
            risk_score_id=risk_score_id,
            escalation_stage="initial",
            auto_escalate_after_seconds=RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS,
            fcm_channel=rule.fcm_channel,
        )

        logger.info(
            "Risk alerts dispatched: device=%s type=%s recipients=%s score=%.2f risk_score_id=%s",
            device_id,
            rule.alert_type,
            recipient_user_ids,
            score,
            risk_score_id,
        )
        return True
    except Exception:
        logger.exception("Failed to dispatch risk alerts for device %s (non-fatal)", device_id)
        return False


def calculate_device_risk(
    db: Session,
    *,
    device_id: int,
    user_id: int,
    allow_cached: bool = True,
    dispatch_alerts: bool = True,
) -> RiskCalculationResult:
    """Run the risk pipeline for one device and persist the result.

    Phase 3b: orchestration only. Inference shaping lives in
    :class:`ModelApiHealthAdapter`; persistence lives in
    :class:`RiskPersistenceAdapter`. Cooldown caching, vitals fetch and
    alert dispatch stay here as orchestration glue.
    """
    risk_type = "general"

    if allow_cached:
        cached_result = _try_cached_risk_result(db, device_id, risk_type)
        if cached_result is not None:
            return cached_result

    if user_id is None:
        logger.warning("Risk calculation skipped: device %s has no assigned user", device_id)
        raise ValueError(f"Device {device_id} is not assigned to any user")

    context = load_device_owner_context(db, device_id)
    vitals_row = _fetch_latest_vitals(db, device_id)
    if vitals_row is None:
        raise ValueError(f"No vitals data found for device {device_id}")

    inference_payload, defaults_applied = _build_inference_payload(vitals_row, context)
    feature_snapshot = describe_feature_vector(inference_payload)

    # Try the external healthguard-model-api first (real SHAP + LightGBM).
    # On any failure fall back to local ``infer_risk`` (ONNX / LightGBM /
    # rule_based) so risk calc never breaks because of model-api outages.
    # Phase 7: ``build_record`` and ``model_api_call`` are timed
    # separately so the timing dashboard can distinguish payload
    # construction from upstream latency. The model-api client itself
    # owns the ``model_api_call`` StageTimer (see ``ModelApiClient``).
    model_api_response: dict[str, Any] | None = None
    try:
        with StageTimer("build_record", device_id=int(device_id)):
            model_record = ModelApiHealthAdapter.to_record(inference_payload)
        model_api_response = get_model_api_client().predict_health_risk(
            model_record,
            user_id=context.get("user_id"),
            device_id=context.get("device_id"),
        )
    except Exception:  # noqa: BLE001 - never let model-api errors break risk calc
        logger.exception(
            "Model-api health predict raised; falling back to local rule_based for device %s",
            device_id,
        )
        model_api_response = None

    if model_api_response is not None:
        inference = ModelApiHealthAdapter.from_response(
            model_api_response,
            defaults_applied=defaults_applied,
            feature_snapshot=feature_snapshot,
        )
    else:
        inference = ModelApiHealthAdapter.from_local_inference(
            infer_risk(inference_payload),
            defaults_applied=defaults_applied,
            feature_snapshot=feature_snapshot,
        )

    with StageTimer(
        "persist",
        device_id=int(device_id),
        backend=inference.backend_label,
    ):
        risk_score_row = RiskPersistenceAdapter.persist(
            db,
            user_id=int(user_id),
            device_id=int(device_id),
            inference=inference,
            vitals_row=vitals_row,
            feature_snapshot=feature_snapshot,
            defaults_applied=defaults_applied,
            risk_type=risk_type,
        )

    result = RiskCalculationResult(
        risk_score_id=risk_score_row.id,
        score=round(float(inference.risk_score), 2),
        risk_level=inference.risk_level,
        model=inference.backend_label,
        calculated_at=risk_score_row.calculated_at,
        # XR-003 / HS-024: tag tentative when confidence < 0.5
        # (synthetic defaults or degraded model-api response).
        is_tentative=inference.confidence_value < 0.5,
    )

    if dispatch_alerts:
        dispatch_risk_alerts(
            db,
            device_id=int(device_id),
            user_id=int(user_id),
            risk_level=inference.risk_level,
            score=result.score,
            risk_score_id=risk_score_row.id,
        )

    return result


def _try_cached_risk_result(
    db: Session,
    device_id: int,
    risk_type: str,
) -> RiskCalculationResult | None:
    """Return a cached :class:`RiskCalculationResult` if within cooldown.

    Extracted from ``calculate_device_risk`` in Phase 3b so the orchestrator
    body stays under 100 lines and the cooldown logic is testable in
    isolation.
    """
    last_calc = (
        db.query(func.max(RiskScore.calculated_at))
        .filter(RiskScore.device_id == int(device_id))
        .filter(RiskScore.risk_type == risk_type)
        .scalar()
    )
    if last_calc is None:
        return None
    elapsed = (get_current_time() - last_calc).total_seconds()
    if elapsed >= RISK_COOLDOWN_SECONDS:
        return None
    cached = (
        db.query(RiskScore)
        .filter(RiskScore.device_id == int(device_id))
        .filter(RiskScore.risk_type == risk_type)
        .order_by(RiskScore.calculated_at.desc())
        .first()
    )
    if cached is None:
        return None
    logger.info(
        "Risk calculation cooldown active: device=%s returning cached result (%.0fs remaining)",
        device_id,
        RISK_COOLDOWN_SECONDS - elapsed,
    )
    return RiskCalculationResult(
        risk_score_id=cached.id,
        score=round(float(cached.score), 2),
        risk_level=(cached.risk_level or "medium").lower(),
        model=cached.algorithm or "unknown",
        calculated_at=cached.calculated_at,
    )
