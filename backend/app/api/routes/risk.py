from __future__ import annotations

import json
from decimal import Decimal
from datetime import UTC, date, datetime
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, get_optional_current_user
from app.db.database import get_db
from app.models.user_model import User
from app.services.risk_inference_service import describe_feature_vector, infer_risk



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
        0: "LOW",
        1: "CRITICAL",
        2: "MEDIUM",
    }
    return mapping.get(int(label_id), "MEDIUM")


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

    inserted_row = db.execute(
        text(
            """
            INSERT INTO risk_scores (
                user_id,
                device_id,
                calculated_at,
                risk_type,
                score,
                risk_level,
                features,
                model_version,
                algorithm
            )
            VALUES (
                :user_id,
                :device_id,
                NOW(),
                'general',
                :score,
                :risk_level,
                CAST(:features AS jsonb),
                :model_version,
                :algorithm
            )
            RETURNING id, calculated_at::text
            """
        ),
        {
            "user_id": int(context["user_id"]),
            "device_id": int(payload.device_id),
            "score": round(float(inference_result.score), 2),
            "risk_level": risk_level.lower(),
            "features": json.dumps(features_json, cls=_DecimalEncoder),
            "model_version": f"{inference_result.backend}-v1.0",
            "algorithm": inference_result.backend,
        },
    ).mappings().first()

    if inserted_row is None:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Không thể lưu risk score",
        )

    db.execute(
        text(
            """
            INSERT INTO risk_explanations (
                risk_score_id,
                explanation_text,
                feature_importance,
                xai_method,
                recommendations
            )
            VALUES (
                :risk_score_id,
                :explanation_text,
                CAST(:feature_importance AS jsonb),
                :xai_method,
                :recommendations
            )
            """
        ),
        {
            "risk_score_id": int(inserted_row["id"]),
            "explanation_text": explanation_text,
            "feature_importance": json.dumps(feature_importance, cls=_DecimalEncoder),
            "xai_method": "rule_based" if inference_result.backend == "rule_based" else "shap",
            "recommendations": [
                "Review recent vitals and repeat the measurement if symptoms persist.",
                "Escalate to medical review for CRITICAL results.",
            ],
        },
    )
    db.commit()

    return RiskCalculateResponse(
        risk_score_id=int(inserted_row["id"]),
        score=round(float(inference_result.score), 2),
        risk_level=risk_level,
        model=inference_result.backend,
        calculated_at=str(inserted_row["calculated_at"]),
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
                re.explanation_text
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

    items = [RiskScoreItem(**dict(row)) for row in rows]
    return RiskScoreListResponse(items=items, total=len(items))
