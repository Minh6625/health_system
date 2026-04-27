from __future__ import annotations

import json
import logging
import os
from decimal import Decimal
from datetime import UTC, date, datetime
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, field_validator
from sqlalchemy import func, text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_optional_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.services.risk_inference_service import describe_feature_vector, infer_risk
from app.models.risk_score_model import RiskScore
from app.models.risk_explanation_model import RiskExplanation
from app.utils.datetime_helper import get_current_time
from app.core.alert_constants import get_escalation_rule
from app.schemas.emergency import RiskAlertResponseRequest, RiskAlertResponseResponse
from app.services.emergency_service import EmergencyService
from app.services.notification_service import NotificationService
from app.services.push_notification_service import PushNotificationService
from app.services.risk_alert_service import (
    RISK_ALERT_AUTO_ESCALATE_AFTER_SECONDS,
    calculate_device_risk,
    dispatch_risk_alerts,
)



logger = logging.getLogger(__name__)
RISK_COOLDOWN_SECONDS = int(os.getenv("RISK_COOLDOWN_SECONDS", "60"))


class _DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super().default(o)

router = APIRouter(tags=["mobile-risk"])


class RiskCalculateRequest(BaseModel):
    device_id: int


class RiskCalculateResponse(BaseModel):
    risk_score_id: int
    score: float
    risk_level: str
    model: str
    calculated_at: str


class RiskScoreItem(BaseModel):
    id: int
    risk_type: str
    score: float
    risk_level: str | None
    algorithm: str | None
    model_version: str | None
    calculated_at: str
    explanation_text: str | None = None
    confidence: float = 0.0

    @field_validator('risk_level', mode='before')
    @classmethod
    def _normalize_risk_level(cls, v: str | None) -> str | None:
        return v.lower() if v else None


class RiskScoreListResponse(BaseModel):
    items: list[RiskScoreItem]
    total: int


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


def _risk_level_from_label_id(label_id: int) -> str:
    mapping = {
        0: "low",
        1: "critical",
        2: "medium",
    }
    return mapping.get(int(label_id), "medium")


def _load_device_owner_context(db: Session, device_id: int) -> dict[str, Any]:
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


def _resolve_calculate_user_context(
    *,
    device_id: int,
    current_user: User | None,
    x_internal_service: str | None,
    db: Session,
) -> dict[str, Any]:
    context = _load_device_owner_context(db, device_id)
    internal_service = (x_internal_service or "").strip().lower()

    if internal_service == "iot-simulator":
        return context

    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Cần xác thực để truy cập endpoint này",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if int(current_user.id) != int(context["user_id"]):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Không có quyền truy cập thiết bị này",
        )

    return context


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



def _dispatch_risk_alerts(
    db: Session,
    *,
    device_id: int,
    user_id: int,
    risk_level: str,
    score: float,
    risk_score_id: int,
) -> None:
    dispatch_risk_alerts(
        db,
        device_id=device_id,
        user_id=user_id,
        risk_level=risk_level,
        score=score,
        risk_score_id=risk_score_id,
    )


@router.post(
    "/risk/alerts/{notification_id}/respond",
    response_model=RiskAlertResponseResponse,
)
def respond_to_risk_alert(
    notification_id: int,
    payload: RiskAlertResponseRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RiskAlertResponseResponse:
    result = EmergencyService.respond_to_risk_alert(
        db,
        current_user_id=int(current_user.id),
        notification_id=notification_id,
        response_action=payload.action,
        risk_score_id=payload.risk_score_id,
        source=payload.source,
        device_id=payload.device_id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        address=payload.address,
        notes=payload.notes,
    )
    return RiskAlertResponseResponse(**result)


@router.post("/risk/recalculate", response_model=RiskCalculateResponse)
def recalculate_risk(
    current_user: User = Depends(get_current_user),
    x_target_profile_id: int | None = Header(default=None, alias="X-Target-Profile-Id"),
    db: Session = Depends(get_db),
) -> RiskCalculateResponse:
    """Force a fresh risk calculation, bypassing the 6-hour cache.

    The endpoint resolves the caller's active device automatically — no
    ``device_id`` is required in the request body.  When an
    ``X-Target-Profile-Id`` header is present (linked-profile flow) the
    device lookup uses that profile's ID instead.
    """
    target_user_id = int(x_target_profile_id) if x_target_profile_id else int(current_user.id)

    row = db.execute(
        text(
            """
            SELECT id FROM devices
            WHERE user_id = :uid
              AND is_active = true
              AND deleted_at IS NULL
            ORDER BY id DESC
            LIMIT 1
            """
        ),
        {"uid": target_user_id},
    ).mappings().first()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy thiết bị đang hoạt động cho tài khoản này",
        )

    result = calculate_device_risk(
        db,
        device_id=int(row["id"]),
        user_id=target_user_id,
        allow_cached=False,
        dispatch_alerts=True,
    )
    return RiskCalculateResponse(
        risk_score_id=result.risk_score_id,
        score=result.score,
        risk_level=result.risk_level,
        model=result.model,
        calculated_at=str(result.calculated_at),
    )


@router.post("/risk/calculate", response_model=RiskCalculateResponse)
def calculate_risk(
    payload: RiskCalculateRequest,
    x_internal_service: str | None = Header(default=None, alias="X-Internal-Service"),
    current_user: User | None = Depends(get_optional_current_user),
    db: Session = Depends(get_db),
) -> RiskCalculateResponse:
    context = _resolve_calculate_user_context(
        device_id=payload.device_id,
        current_user=current_user,
        x_internal_service=x_internal_service,
        db=db,
    )
    result = calculate_device_risk(
        db,
        device_id=int(payload.device_id),
        user_id=int(context["user_id"]),
        allow_cached=True,
        dispatch_alerts=True,
    )
    return RiskCalculateResponse(
        risk_score_id=result.risk_score_id,
        score=result.score,
        risk_level=result.risk_level,
        model=result.model,
        calculated_at=str(result.calculated_at),
    )


@router.get("/risk/latest", response_model=RiskScoreListResponse)
def get_latest_risk_scores(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(default=5, ge=1, le=20),
) -> RiskScoreListResponse:
    rows = db.execute(
        text(
            """
            SELECT
                rs.id,
                rs.risk_type,
                rs.score,
                rs.risk_level,
                rs.algorithm,
                rs.model_version,
                rs.calculated_at::text AS calculated_at,
                re.explanation_text,
                rs.features
            FROM risk_scores AS rs
            LEFT JOIN LATERAL (
                SELECT explanation_text
                FROM risk_explanations
                WHERE risk_score_id = rs.id
                ORDER BY id DESC
                LIMIT 1
            ) AS re ON TRUE
            WHERE rs.user_id = :user_id
            ORDER BY rs.calculated_at DESC
            LIMIT :limit
            """
        ),
        {"user_id": int(current_user.id), "limit": int(limit)},
    ).mappings().all()

    items = [RiskScoreItem(**{**dict(row), "confidence": _extract_confidence(dict(row).get("features"))}) for row in rows]
    return RiskScoreListResponse(items=items, total=len(items))




# ---------------------------------------------------------------------------
# Task 3.16 -- Extract confidence from features JSON blob
# ---------------------------------------------------------------------------


def _extract_confidence(risk_score_or_features) -> float:
    """Extract confidence from the features JSON blob. Default 0.0."""
    if risk_score_or_features is None:
        return 0.0
    # Accept either a RiskScore ORM object or raw features value
    features = getattr(risk_score_or_features, 'features', risk_score_or_features)
    if not features:
        return 0.0
    try:
        data = json.loads(features) if isinstance(features, str) else features
        return float(data.get('confidence', 0.0))
    except (json.JSONDecodeError, TypeError, ValueError, AttributeError):
        return 0.0


# ---------------------------------------------------------------------------
# Task 3.17 -- trend7d and previousScore helpers
# ---------------------------------------------------------------------------


def _compute_trend7d(db: Session, user_id: int, risk_type: str, reference_date) -> list[int | None]:
    """Compute daily max scores for the last 7 days. Index 0 = 6 days ago, index 6 = today."""
    from datetime import timedelta
    result: list[int | None] = []
    ref_date = reference_date.date() if hasattr(reference_date, 'date') else reference_date
    for days_ago in range(6, -1, -1):
        day = ref_date - timedelta(days=days_ago)
        day_start = datetime.combine(day, datetime.min.time())
        day_end = datetime.combine(day, datetime.max.time())
        max_score = db.query(func.max(RiskScore.score)).filter(
            RiskScore.user_id == user_id,
            RiskScore.risk_type == risk_type,
            RiskScore.calculated_at >= day_start,
            RiskScore.calculated_at <= day_end,
        ).scalar()
        result.append(int(max_score) if max_score is not None else None)
    return result


def _get_previous_score(db: Session, user_id: int, risk_type: str, current_id: int) -> int | None:
    """Get score of the immediately preceding risk calculation."""
    prev = db.query(RiskScore.score).filter(
        RiskScore.user_id == user_id,
        RiskScore.risk_type == risk_type,
        RiskScore.id < current_id,
    ).order_by(RiskScore.id.desc()).first()
    return int(prev[0]) if prev else None


# ---------------------------------------------------------------------------
# Task 3.10 -- Feature metadata & breakdown helper for Flutter FactorBreakdown
# ---------------------------------------------------------------------------

_FEATURE_META: dict[str, dict[str, str]] = {
    "heart_rate": {"label": "Heart Rate", "unit": "bpm"},
    "spo2": {"label": "SpO2", "unit": "%"},
    "systolic_bp": {"label": "Systolic BP", "unit": "mmHg"},
    "diastolic_bp": {"label": "Diastolic BP", "unit": "mmHg"},
    "temperature": {"label": "Temperature", "unit": "°C"},
    "respiration_rate": {"label": "Respiration Rate", "unit": "br/min"},
    "hrv": {"label": "Heart Rate Variability", "unit": "ms"},
    "stress_level": {"label": "Stress Level", "unit": ""},
    "sleep_quality": {"label": "Sleep Quality", "unit": ""},
    "activity_level": {"label": "Activity Level", "unit": ""},
    "steps": {"label": "Steps", "unit": "steps"},
    "calories": {"label": "Calories Burned", "unit": "kcal"},
    "age": {"label": "Age", "unit": "years"},
    "bmi": {"label": "BMI", "unit": "kg/m²"},
}


def _build_breakdown(feature_importance: dict[str, float] | None) -> list[dict[str, "Any"]]:
    """Transform feature_importance dict into Flutter FactorBreakdown list."""
    if not feature_importance:
        return []
    breakdown: list[dict[str, "Any"]] = []
    for key, score in feature_importance.items():
        meta = _FEATURE_META.get(key, {"label": key.replace("_", " ").title(), "unit": ""})
        if score > 0.5:
            impact = "high"
        elif score > 0.2:
            impact = "medium"
        else:
            impact = "low"
        breakdown.append({
            "key": key,
            "label": meta["label"],
            "contributionScore": round(float(score), 4),
            "impactLevel": impact,
            "unit": meta["unit"],
        })
    # Sort by contributionScore descending
    breakdown.sort(key=lambda x: x["contributionScore"], reverse=True)
    return breakdown


# ---------------------------------------------------------------------------
# Task 3.4 -- GET /risk/{risk_score_id}/detail
# ---------------------------------------------------------------------------


@router.get("/risk/{risk_score_id}/detail")
def get_risk_detail(
    risk_score_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    """Return detailed risk score with explanation data."""
    risk_score = db.query(RiskScore).filter(RiskScore.id == risk_score_id).first()

    if risk_score is None:
        raise HTTPException(status_code=404, detail="Risk score not found")

    if risk_score.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")

    # Get first explanation (if any)
    explanation = risk_score.explanations[0] if risk_score.explanations else None

    return {
        "id": risk_score.id,
        "risk_type": risk_score.risk_type,
        "score": float(risk_score.score),
        "risk_level": risk_score.risk_level.lower() if risk_score.risk_level else None,
        "calculated_at": str(risk_score.calculated_at),
        "algorithm": risk_score.algorithm,
        "model_version": risk_score.model_version,
        "explanation_text": explanation.explanation_text if explanation else None,
        "feature_importance": explanation.feature_importance if explanation else None,
        "breakdown": _build_breakdown(explanation.feature_importance if explanation else None),
        "recommendations": (
            list(explanation.recommendations)
            if explanation and explanation.recommendations
            else None
        ),
        "confidence": _extract_confidence(risk_score),
        "trend7d": _compute_trend7d(db, risk_score.user_id, risk_score.risk_type, risk_score.calculated_at),
        "previousScore": _get_previous_score(db, risk_score.user_id, risk_score.risk_type, risk_score.id),
    }


# ---------------------------------------------------------------------------
# Task 3.5 -- GET /risk/history
# ---------------------------------------------------------------------------


@router.get("/risk/history")
def get_risk_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    risk_type: str | None = Query(default=None),
) -> dict[str, Any]:
    """Return paginated risk score history for the current user."""
    query = db.query(RiskScore).filter(RiskScore.user_id == current_user.id)

    if risk_type:
        query = query.filter(RiskScore.risk_type == risk_type)

    total = query.count()

    rows = (
        query
        .order_by(RiskScore.calculated_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    items = [
        {
            "id": row.id,
            "risk_type": row.risk_type,
            "score": float(row.score),
            "risk_level": row.risk_level.lower() if row.risk_level else None,
            "calculated_at": str(row.calculated_at),
        }
        for row in rows
    ]

    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
    }

