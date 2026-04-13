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

    # --- Task 3.12: Cooldown check ---
    risk_type = "general"  # current hardcoded risk_type
    last_calc = (
        db.query(func.max(RiskScore.calculated_at))
        .filter(RiskScore.device_id == int(payload.device_id))
        .filter(RiskScore.risk_type == risk_type)
        .scalar()
    )
    if last_calc is not None:
        elapsed = (get_current_time() - last_calc).total_seconds()
        if elapsed < RISK_COOLDOWN_SECONDS:
            # Return cached result instead of recalculating
            cached = (
                db.query(RiskScore)
                .filter(RiskScore.device_id == int(payload.device_id))
                .filter(RiskScore.risk_type == risk_type)
                .order_by(RiskScore.calculated_at.desc())
                .first()
            )
            if cached is not None:
                logger.info(
                    "Cooldown active for device %s, returning cached result (%.0fs remaining)",
                    payload.device_id,
                    RISK_COOLDOWN_SECONDS - elapsed,
                )
                return RiskCalculateResponse(
                    risk_score_id=cached.id,
                    score=round(float(cached.score), 2),
                    risk_level=cached.risk_level,
                    model=cached.algorithm or "unknown",
                    calculated_at=str(cached.calculated_at),
                )

    # --- Task 3.13: Guard against NULL user_id ---
    if context.get("user_id") is None:
        logger.warning("Risk calculation skipped: device %s has no assigned user", payload.device_id)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Device not assigned to any user",
        )

    vitals_row = _fetch_latest_vitals(db, payload.device_id)
    if vitals_row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không có vitals data cho device này",
        )

    inference_payload, defaults_applied = _build_inference_payload(vitals_row, context)
    inference_result = infer_risk(inference_payload)
    feature_snapshot = describe_feature_vector(inference_payload)
    risk_level = _risk_level_from_label_id(inference_result.label_id)
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
        "confidence": inference_result.confidence,
        "fallback_reason": inference_result.fallback_reason,
    }
    # Sanitize Decimal values so JSONB serialization works
    features_json = json.loads(json.dumps(features_json, cls=_DecimalEncoder))

    try:
        risk_score = RiskScore(
            user_id=int(context["user_id"]),
            device_id=int(payload.device_id),
            calculated_at=get_current_time(),
            risk_type="general",
            score=round(float(inference_result.score), 2),
            risk_level=risk_level.lower(),
            features=features_json,
            model_version=f"{inference_result.backend}-v1.0",
            algorithm=inference_result.backend,
        )
        db.add(risk_score)
        db.flush()

        risk_explanation = RiskExplanation(
            risk_score_id=risk_score.id,
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
        db.refresh(risk_score)
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể lưu risk score",
        )

    return RiskCalculateResponse(
        risk_score_id=risk_score.id,
        score=round(float(inference_result.score), 2),
        risk_level=risk_level,
        model=inference_result.backend,
        calculated_at=str(risk_score.calculated_at),
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


# ---------------------------------------------------------------------------
# Task 3.9 - GET /analysis/risk-reports (Flutter path alias for /risk/latest)
# ---------------------------------------------------------------------------


@router.get('/analysis/risk-reports', response_model=RiskScoreListResponse)
def get_risk_reports_alias(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    limit: int = Query(default=5, ge=1, le=20),
) -> RiskScoreListResponse:
    """Alias for ``/risk/latest`` -- matches Flutter ``/analysis/risk-reports`` path."""
    return get_latest_risk_scores(current_user=current_user, db=db, limit=limit)
