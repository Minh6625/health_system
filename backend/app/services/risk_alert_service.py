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
from app.repositories.emergency_repository import EmergencyRepository
from app.services.model_api_client import get_model_api_client
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

# Mapping from model-api feature names (HealthGuard schema) to backend / UI canonical keys.
_MODEL_API_FEATURE_ALIASES: dict[str, str] = {
    "respiratory_rate": "resp_rate",
    "body_temperature": "body_temp",
    "systolic_blood_pressure": "sys_bp",
    "diastolic_blood_pressure": "dia_bp",
    "derived_hrv": "hrv",
    "derived_pulse_pressure": "pulse_pressure",
    "derived_bmi": "bmi",
    "derived_map": "map_val",
}

# Mapping model-api `risk_level` (normal|warning|critical) to backend canonical (low|medium|critical).
_MODEL_API_RISK_LEVEL_MAP: dict[str, str] = {
    "normal": "low",
    "warning": "medium",
    "high": "medium",
    "moderate": "medium",
    "medium": "medium",
    "critical": "critical",
    "low": "low",
}


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


def _build_model_api_record(payload: dict[str, Any]) -> dict[str, Any]:
    """Map ``risk_inference_service`` payload schema to the model-api ``VitalSignsRecord``.

    Computes the four derived features (HRV / pulse-pressure / BMI / MAP) so that
    `health_service.prepare_inference_frame` accepts the record without falling back
    to its own ``ValueError("Missing required keys")`` path.
    """
    sys_bp = float(payload.get("sys_bp") or 120.0)
    dia_bp = float(payload.get("dia_bp") or 80.0)
    height_cm = float(payload.get("height_cm") or 165.0)
    height_m = height_cm / 100.0 if height_cm > 3.5 else height_cm
    if height_m <= 0:
        height_m = 1.65
    weight_kg = float(payload.get("weight_kg") or 65.0)
    hrv = float(payload.get("hrv") or 50.0)
    gender_norm = str(payload.get("gender") or "").strip().lower()
    gender_int = 1 if gender_norm in {"m", "male", "man", "nam", "1", "true"} else 0

    return {
        "heart_rate": float(payload.get("heart_rate") or 75.0),
        "respiratory_rate": float(payload.get("resp_rate") or 16.0),
        "body_temperature": float(payload.get("body_temp") or 36.6),
        "spo2": float(payload.get("spo2") or 98.0),
        "systolic_blood_pressure": sys_bp,
        "diastolic_blood_pressure": dia_bp,
        "age": int(round(float(payload.get("age") or 35.0))),
        "gender": gender_int,
        "weight_kg": weight_kg,
        "height_m": round(height_m, 4),
        "derived_hrv": hrv,
        "derived_pulse_pressure": round(sys_bp - dia_bp, 4),
        "derived_bmi": round(weight_kg / (height_m * height_m), 4),
        "derived_map": round((sys_bp + 2.0 * dia_bp) / 3.0, 4),
    }


def _map_model_api_risk_level(raw_level: str | None) -> str | None:
    if not raw_level:
        return None
    return _MODEL_API_RISK_LEVEL_MAP.get(str(raw_level).strip().lower())


def _alias_feature_name(feature_name: str) -> str:
    return _MODEL_API_FEATURE_ALIASES.get(feature_name, feature_name)


def _normalize_model_api_top_features(
    top_features: list[dict[str, Any]] | None,
) -> list[dict[str, Any]]:
    """Rewrite ``feature`` keys to backend/UI canonical names; drop invalid entries."""
    if not top_features:
        return []
    normalized: list[dict[str, Any]] = []
    for entry in top_features:
        if not isinstance(entry, dict):
            continue
        feature_name = str(entry.get("feature") or "").strip()
        if not feature_name:
            continue
        item = dict(entry)
        item["feature"] = _alias_feature_name(feature_name)
        normalized.append(item)
    return normalized


def _normalize_model_api_shap(
    shap_payload: dict[str, Any] | None,
) -> dict[str, Any] | None:
    """Alias feature names inside ``shap.values`` so UI can match them to vitals."""
    if not isinstance(shap_payload, dict):
        return None
    values = shap_payload.get("values")
    if not isinstance(values, list):
        return shap_payload
    aliased_values: list[dict[str, Any]] = []
    for entry in values:
        if not isinstance(entry, dict):
            continue
        feature_name = str(entry.get("feature") or "").strip()
        if not feature_name:
            continue
        new_entry = dict(entry)
        new_entry["feature"] = _alias_feature_name(feature_name)
        aliased_values.append(new_entry)
    return {**shap_payload, "values": aliased_values}


def _feature_importance_from_top_features(
    top_features: list[dict[str, Any]] | None,
) -> dict[str, float]:
    """Build legacy ``feature_importance`` dict (key -> impact) from SHAP top_features."""
    if not top_features:
        return {}
    out: dict[str, float] = {}
    for entry in top_features:
        if not isinstance(entry, dict):
            continue
        key = str(entry.get("feature") or "").strip()
        if not key:
            continue
        try:
            out[key] = round(float(entry.get("impact") or 0.0), 4)
        except (TypeError, ValueError):
            continue
    return out


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


def _default_recommendations(risk_level: str) -> list[str]:
    """Risk-level aware recommendations used when model-api explanation is unavailable."""
    normalized = (risk_level or "").strip().lower()
    if normalized == "critical":
        return [
            "Đo lại chỉ số để xác nhận",
            "Đối chiếu triệu chứng hiện tại",
            "Liên hệ nhân viên y tế nếu cần",
        ]
    if normalized in {"medium", "moderate", "high", "warning"}:
        return [
            "Đo lại chỉ số sau 30-60 phút",
            "Theo dõi triệu chứng bất thường",
        ]
    return [
        "Tiếp tục theo dõi định kỳ",
        "Duy trì lịch đo đều đặn",
    ]


def _build_ai_explanation_payload(
    *,
    explanation_text: str,
    risk_level: str,
    recommendations: list[str],
) -> dict[str, Any]:
    """Build minimal AI explanation payload consumed by Flutter.

    Phase A: synthesized from existing explanation_text + rule-based actions so the
    new column is populated even before model-api integration (Phase 3) lands.
    """
    return {
        "short_text": explanation_text,
        "clinical_note": "",
        "recommended_actions": list(recommendations or []),
    }


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
    feature_snapshot = describe_feature_vector(inference_payload)

    # ------------------------------------------------------------------
    # Phase A: try the external healthguard-model-api (real SHAP + LightGBM).
    # If unavailable / disabled / errored -> fall back to local infer_risk()
    # which already covers ONNX, LightGBM and rule_based pipelines.
    # ------------------------------------------------------------------
    model_api_response: dict[str, Any] | None = None
    try:
        model_record = _build_model_api_record(inference_payload)
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
        backend_label = "model_api_health"
        meta = model_api_response.get("meta") if isinstance(model_api_response.get("meta"), dict) else {}
        # `model_version` column is varchar(20). Prefer the model-api ``meta.model_version``
        # (e.g. "v_current") which fits; otherwise short-form "model_api_v1".
        model_version_label = str(meta.get("model_version") or "model_api_v1")[:20]
        raw_level = (
            model_api_response.get("risk_level")
            or (model_api_response.get("prediction") or {}).get("prediction_band")
        )
        risk_level = _map_model_api_risk_level(raw_level) or "medium"
        try:
            probability = float(
                model_api_response.get("predicted_health_risk_probability")
                or (model_api_response.get("prediction") or {}).get("prediction_score")
                or 0.0
            )
        except (TypeError, ValueError):
            probability = 0.0
        confidence_value = max(0.0, min(1.0, probability))
        risk_score = normalize_risk_score(
            level=risk_level,
            confidence=confidence_value,
            raw_score=None,
            backend=backend_label,
        )
        prediction_label = str(
            (model_api_response.get("prediction") or {}).get("prediction_label")
            or model_api_response.get("predicted_health_risk_label")
            or risk_level
        )
        label_id = None
        fallback_reason = None

        top_features = _normalize_model_api_top_features(
            model_api_response.get("top_features")
        )
        shap_details = _normalize_model_api_shap(model_api_response.get("shap"))
        ai_explanation = model_api_response.get("explanation") or {}
        if not isinstance(ai_explanation, dict):
            ai_explanation = {}

        feature_importance = _feature_importance_from_top_features(top_features)
        if not feature_importance:
            feature_importance = _build_feature_importance(feature_snapshot)

        recommendations_raw = ai_explanation.get("recommended_actions") or []
        recommendations = [
            str(item).strip() for item in recommendations_raw if str(item).strip()
        ] or _default_recommendations(risk_level)

        explanation_text = (
            str(ai_explanation.get("short_text") or "").strip()
            or _build_explanation_text(
                risk_level=risk_level,
                backend=backend_label,
                defaults_applied=defaults_applied,
                fallback_reason=None,
            )
        )
        ai_explanation_payload = {
            "short_text": explanation_text,
            "clinical_note": str(ai_explanation.get("clinical_note") or "").strip(),
            "recommended_actions": recommendations,
        }
        xai_method = "shap" if isinstance(shap_details, dict) and shap_details.get("available") else "rule_based"
        artifact_path = (
            (model_api_response.get("meta") or {}).get("artifact_path") if isinstance(model_api_response.get("meta"), dict) else None
        )
    else:
        inference_result = infer_risk(inference_payload)
        risk_level = canonicalize_risk_level(inference_result.label) or "medium"
        confidence_value = float(inference_result.confidence)
        risk_score = normalize_risk_score(
            level=risk_level,
            confidence=inference_result.confidence,
            raw_score=inference_result.score,
            backend=inference_result.backend,
        )
        backend_label = inference_result.backend
        prediction_label = inference_result.label
        label_id = inference_result.label_id
        fallback_reason = inference_result.fallback_reason
        top_features = []
        shap_details = None
        feature_importance = _build_feature_importance(feature_snapshot)
        explanation_text = _build_explanation_text(
            risk_level=risk_level,
            backend=backend_label,
            defaults_applied=defaults_applied,
            fallback_reason=fallback_reason,
        )
        recommendations = _default_recommendations(risk_level)
        ai_explanation_payload = _build_ai_explanation_payload(
            explanation_text=explanation_text,
            risk_level=risk_level,
            recommendations=recommendations,
        )
        xai_method = "rule_based"
        artifact_path = None
        # `model_version` column is varchar(20); local backend labels keep "-v1.0" suffix.
        model_version_label = f"{backend_label}-v1.0"[:20]

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
        "backend": backend_label,
        "label_id": label_id,
        "label": prediction_label,
        "risk_level": risk_level,
        "risk_score": risk_score,
        "health_score": derive_health_score(risk_score),
        "health_level": derive_health_level(risk_level),
        "health_summary": derive_health_summary(risk_level),
        "confidence": confidence_value,
        "fallback_reason": fallback_reason,
        "artifact_path": artifact_path,
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
            model_version=model_version_label,
            algorithm=backend_label,
        )
        db.add(risk_score_row)
        db.flush()

        risk_explanation = RiskExplanation(
            risk_score_id=risk_score_row.id,
            explanation_text=explanation_text,
            feature_importance=feature_importance,
            xai_method=xai_method,
            recommendations=recommendations,
            top_features_json=top_features or None,
            ai_explanation_json=ai_explanation_payload,
            shap_details_json=shap_details if isinstance(shap_details, dict) else None,
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
        model=backend_label,
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
