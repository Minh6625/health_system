from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import func, text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.core.alert_constants import get_escalation_rule
from app.models.risk_explanation_model import RiskExplanation
from app.models.risk_score_model import RiskScore
from app.services.notification_service import NotificationService
from app.services.push_notification_service import PushNotificationService
from app.services.risk_inference_service import (
    canonicalize_risk_level,
    derive_health_level,
    derive_health_score,
    derive_health_summary,
    describe_feature_vector,
    infer_risk,
    normalize_risk_score,
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


class _DecimalEncoder(json.JSONEncoder):
    def default(self, o: Any) -> Any:
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)


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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy thiết bị",
        )

    return dict(row)


def _fetch_latest_vitals(db: Session, device_id: int) -> dict[str, Any] | None:
    query_with_bp = text(
        """
        SELECT
            time,
            heart_rate,
            spo2,
            temperature,
            hrv,
            respiratory_rate,
            blood_pressure_sys,
            blood_pressure_dia
        FROM vitals
        WHERE device_id = :device_id
        ORDER BY time DESC
        LIMIT 1
        """
    )
    query_without_bp = text(
        """
        SELECT
            time,
            heart_rate,
            spo2,
            temperature,
            hrv,
            respiratory_rate,
            NULL AS blood_pressure_sys,
            NULL AS blood_pressure_dia
        FROM vitals
        WHERE device_id = :device_id
        ORDER BY time DESC
        LIMIT 1
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

    return dict(row) if row is not None else None


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


def _build_explanation_text(
    *,
    risk_level: str,
    backend: str,
    defaults_applied: list[str],
    fallback_reason: str | None,
) -> str:
    notes: list[str] = [f"Risk inference backend `{backend}` predicted {risk_level.lower()} risk."]
    if defaults_applied:
        notes.append("Default inputs were used for: " + ", ".join(defaults_applied) + ".")
    if fallback_reason:
        notes.append(f"Fallback reason: {fallback_reason}.")
    return " ".join(notes)


def _build_feature_importance(feature_snapshot: dict[str, float]) -> dict[str, float]:
    importance: dict[str, float] = {}
    for key in ("heart_rate", "spo2", "sys_bp", "dia_bp", "resp_rate", "body_temp", "hrv"):
        value = feature_snapshot.get(key)
        if value is not None:
            importance[key] = round(abs(float(value)), 4)
    return importance


def dispatch_risk_alerts(
    db: Session,
    *,
    device_id: int,
    user_id: int,
    risk_level: str,
    score: float,
    risk_score_id: int | None = None,
) -> bool:
    """Escalation -> cooldown check -> create alerts -> send push notifications."""
    rule = get_escalation_rule(risk_level)
    if rule is None:
        logger.info("Risk alert skipped: level=%s does not require alerting", risk_level)
        return False

    assert rule.alert_type is not None
    assert rule.severity is not None

    if NotificationService.is_risk_alert_in_cooldown(
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
        recipient_user_ids = [int(user_id)]
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
    risk_type = "general"

    if allow_cached:
        last_calc = (
            db.query(func.max(RiskScore.calculated_at))
            .filter(RiskScore.device_id == int(device_id))
            .filter(RiskScore.risk_type == risk_type)
            .scalar()
        )
        if last_calc is not None:
            elapsed = (get_current_time() - last_calc).total_seconds()
            if elapsed < RISK_COOLDOWN_SECONDS:
                cached = (
                    db.query(RiskScore)
                    .filter(RiskScore.device_id == int(device_id))
                    .filter(RiskScore.risk_type == risk_type)
                    .order_by(RiskScore.calculated_at.desc())
                    .first()
                )
                if cached is not None:
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

    if user_id is None:
        logger.warning("Risk calculation skipped: device %s has no assigned user", device_id)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Device not assigned to any user",
        )

    context = load_device_owner_context(db, device_id)
    vitals_row = _fetch_latest_vitals(db, device_id)
    if vitals_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không có vitals data cho device này",
        )

    inference_payload, defaults_applied = _build_inference_payload(vitals_row, context)
    inference_result = infer_risk(inference_payload)
    feature_snapshot = describe_feature_vector(inference_payload)
    risk_level = canonicalize_risk_level(inference_result.label) or "medium"
    risk_score = normalize_risk_score(
        level=risk_level,
        confidence=inference_result.confidence,
        raw_score=inference_result.score,
        backend=inference_result.backend,
    )
    explanation_text = _build_explanation_text(
        risk_level=risk_level,
        backend=inference_result.backend,
        defaults_applied=defaults_applied,
        fallback_reason=inference_result.fallback_reason,
    )
    feature_importance = _build_feature_importance(feature_snapshot)

    features_json = {
        "model_features": feature_snapshot,
        "raw_vitals": {
            "heart_rate": vitals_row.get("heart_rate"),
            "spo2": vitals_row.get("spo2"),
            "temperature": vitals_row.get("temperature"),
            "respiratory_rate": vitals_row.get("respiratory_rate"),
            "blood_pressure_sys": vitals_row.get("blood_pressure_sys"),
            "blood_pressure_dia": vitals_row.get("blood_pressure_dia"),
            "hrv": vitals_row.get("hrv"),
        },
        "defaults_applied": defaults_applied,
        "backend": inference_result.backend,
        "label_id": inference_result.label_id,
        "label": inference_result.label,
        "risk_level": risk_level,
        "risk_score": risk_score,
        "health_score": derive_health_score(risk_score),
        "health_level": derive_health_level(risk_level),
        "health_summary": derive_health_summary(risk_level),
        "confidence": inference_result.confidence,
        "fallback_reason": inference_result.fallback_reason,
    }
    features_json = json.loads(json.dumps(features_json, cls=_DecimalEncoder))

    try:
        risk_score_row = RiskScore(
            user_id=int(user_id),
            device_id=int(device_id),
            calculated_at=get_current_time(),
            risk_type="general",
            score=round(float(risk_score), 2),
            risk_level=risk_level,
            features=features_json,
            model_version=f"{inference_result.backend}-v1.0",
            algorithm=inference_result.backend,
        )
        db.add(risk_score_row)
        db.flush()

        risk_explanation = RiskExplanation(
            risk_score_id=risk_score_row.id,
            explanation_text=explanation_text,
            feature_importance=feature_importance,
            xai_method="rule_based" if inference_result.backend == "rule_based" else "shap",
            recommendations=[
                "Review recent vitals and repeat the measurement if symptoms persist.",
                "Escalate to medical review for CRITICAL results.",
            ],
        )
        db.add(risk_explanation)
        db.commit()
        db.refresh(risk_score_row)
    except Exception:
        db.rollback()
        logger.exception("Failed to persist risk score for device %s", device_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể lưu risk score",
        )

    result = RiskCalculationResult(
        risk_score_id=risk_score_row.id,
        score=round(float(risk_score), 2),
        risk_level=risk_level,
        model=inference_result.backend,
        calculated_at=risk_score_row.calculated_at,
    )

    if dispatch_alerts:
        dispatch_risk_alerts(
            db,
            device_id=int(device_id),
            user_id=int(user_id),
            risk_level=risk_level,
            score=result.score,
            risk_score_id=risk_score_row.id,
        )

    return result
