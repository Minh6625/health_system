from __future__ import annotations

import json as _json
import logging
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.device_model import Device
from app.models.sos_event_model import Alert, FallEvent
from app.services.settings_service import SettingsService

router = APIRouter(prefix="/telemetry", tags=["mobile-telemetry"])
logger = logging.getLogger(__name__)


class VitalIngestVitals(BaseModel):
    model_config = ConfigDict(extra="allow")

    heart_rate: float | None = None
    spo2: float | None = None
    temperature: float | None = None
    hrv: float | None = None
    respiratory_rate: float | None = None
    blood_pressure_sys: float | None = None
    blood_pressure_dia: float | None = None
    signal_quality: float | None = None
    motion_artifact: bool | None = None


class VitalIngestItem(BaseModel):
    db_device_id: int
    emitted_at: datetime
    vitals: VitalIngestVitals


class VitalIngestRequest(BaseModel):
    messages: list[VitalIngestItem]


class IngestResponse(BaseModel):
    ingested: int
    errors: list[str] = Field(default_factory=list)


class AlertIngestRequest(BaseModel):
    db_device_id: int
    user_id: int | None = None
    event_type: str
    severity: str
    timestamp: datetime
    metadata: dict[str, Any] = Field(default_factory=dict)


class SleepIngestRequest(BaseModel):
    db_device_id: int
    user_id: int
    date: str
    score: int
    efficiency: float
    duration_minutes: int
    phases: dict[str, int]
    start_time: datetime
    end_time: datetime


def _pick_value(payload: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in payload and payload[key] is not None:
            return payload[key]
    return None


def _pick_float(payload: dict[str, Any], *keys: str) -> float | None:
    value = _pick_value(payload, *keys)
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _pick_int(payload: dict[str, Any], *keys: str) -> int | None:
    value = _pick_float(payload, *keys)
    if value is None:
        return None
    return int(round(value))


def _pick_bool(payload: dict[str, Any], *keys: str) -> bool | None:
    value = _pick_value(payload, *keys)
    if value is None:
        return None
    return bool(value)


def _resolve_alert_user_id(
    db: Session,
    *,
    db_device_id: int,
    explicit_user_id: int | None,
) -> int | None:
    if explicit_user_id is not None:
        return explicit_user_id
    return (
        db.query(Device.user_id)
        .filter(Device.id == db_device_id)
        .scalar()
    )


def _map_alert_severity(severity: str) -> str:
    normalized = (severity or "").strip().lower()
    if normalized == "warning":
        return "high"
    if normalized == "critical":
        return "critical"
    if normalized == "high":
        return "high"
    return "normal"


def _map_alert_type(event_type: str) -> str:
    normalized = (event_type or "").strip().lower()
    if normalized == "fall_detected":
        return "fall_detection"
    if normalized == "vitals_out_of_range":
        return "vitals_threshold"
    return normalized or "generic_alert"


def _build_alert_title(event_type: str, severity: str) -> str:
    normalized = (event_type or "").strip().lower()
    if normalized == "fall_detected":
        return "Fall detected"
    if severity == "critical":
        return "Critical vital signs detected"
    if severity == "high":
        return "Warning vital signs detected"
    return normalized.replace("_", " ").strip().title() or "Telemetry alert"


@router.post("/ingest", response_model=IngestResponse)
def ingest_vitals(
    payload: VitalIngestRequest,
    db: Session = Depends(get_db),
) -> IngestResponse:
    insert_sql = text(
        """
        INSERT INTO vitals (
            time,
            device_id,
            heart_rate,
            spo2,
            temperature,
            hrv,
            respiratory_rate,
            blood_pressure_sys,
            blood_pressure_dia,
            signal_quality,
            motion_artifact
        ) VALUES (
            :time,
            :device_id,
            :heart_rate,
            :spo2,
            :temperature,
            :hrv,
            :respiratory_rate,
            :blood_pressure_sys,
            :blood_pressure_dia,
            :signal_quality,
            :motion_artifact
        )
        ON CONFLICT (device_id, time) DO NOTHING
        """
    )

    ingested = 0
    errors: list[str] = []

    for index, message in enumerate(payload.messages):
        vitals = message.vitals.model_dump()
        if message.vitals.model_extra:
            vitals.update(message.vitals.model_extra)
        params = {
            "time": message.emitted_at,
            "device_id": message.db_device_id,
            "heart_rate": _pick_float(vitals, "heart_rate"),
            "spo2": _pick_float(vitals, "spo2"),
            "temperature": _pick_float(vitals, "temperature"),
            "hrv": _pick_float(vitals, "hrv"),
            "respiratory_rate": _pick_float(vitals, "respiratory_rate"),
            "blood_pressure_sys": _pick_int(vitals, "blood_pressure_sys", "sys_bp"),
            "blood_pressure_dia": _pick_int(vitals, "blood_pressure_dia", "dia_bp"),
            "signal_quality": _pick_float(vitals, "signal_quality"),
            "motion_artifact": _pick_bool(vitals, "motion_artifact"),
        }

        try:
            with db.begin_nested():
                result = db.execute(insert_sql, params)
            ingested += max(result.rowcount or 0, 0)
        except Exception as exc:
            errors.append(
                f"messages[{index}] device_id={message.db_device_id}: {exc}"
            )

    try:
        db.commit()

        if ingested > 0:
            pushed_device_ids = list({msg.db_device_id for msg in payload.messages})
            try:
                db.execute(
                    text(
                        """
                        UPDATE devices
                        SET last_sync_at = NOW()
                        WHERE id = ANY(:device_ids)
                          AND deleted_at IS NULL
                        """
                    ),
                    {"device_ids": pushed_device_ids},
                )
                db.commit()
            except Exception as sync_exc:
                db.rollback()
                errors.append(f"last_sync_update_failed: {sync_exc}")
    except Exception as exc:
        db.rollback()
        ingested = 0
        errors.append(f"commit_failed: {exc}")

    return IngestResponse(ingested=ingested, errors=errors)


@router.post("/alert", response_model=IngestResponse)
def ingest_alert(
    payload: AlertIngestRequest,
    db: Session = Depends(get_db),
) -> IngestResponse:
    errors: list[str] = []
    ingested = 0

    try:
        metadata = dict(payload.metadata or {})
        if str(metadata.get("sleep_context") or "").strip().lower() == "true":
            sleep_thresholds = SettingsService.get_vitals_sleep_thresholds(db)
            logger.info(
                "Sleep-context alert received: event_type=%s sleep_spo2_critical=%s apnea_rr_threshold=%s",
                payload.event_type,
                sleep_thresholds.get("spo2_critical"),
                sleep_thresholds.get("apnea_rr_threshold"),
            )
        resolved_user_id = _resolve_alert_user_id(
            db,
            db_device_id=payload.db_device_id,
            explicit_user_id=payload.user_id,
        )
        fall_event_id: int | None = None

        if payload.event_type == "fall_detected":
            fall_event = FallEvent(
                device_id=payload.db_device_id,
                detected_at=payload.timestamp,
                confidence=_pick_float(metadata, "confidence") or 0.0,
                model_version=_pick_value(metadata, "model_version"),
                latitude=_pick_float(metadata, "latitude"),
                longitude=_pick_float(metadata, "longitude"),
                location_accuracy=_pick_float(metadata, "location_accuracy", "accuracy"),
                address=_pick_value(metadata, "address"),
                features=metadata or None,
            )
            db.add(fall_event)
            db.flush()
            fall_event_id = fall_event.id
            ingested += 1

        mapped_severity = _map_alert_severity(payload.severity)
        alert_type = _map_alert_type(payload.event_type)
        alert = Alert(
            device_id=payload.db_device_id,
            user_id=resolved_user_id,
            fall_event_id=fall_event_id,
            alert_type=alert_type,
            severity=mapped_severity,
            title=_build_alert_title(payload.event_type, mapped_severity),
            message=_pick_value(metadata, "message"),
            details=metadata or None,
        )
        db.add(alert)
        db.commit()
        ingested += 1
    except Exception as exc:
        db.rollback()
        errors.append(f"alert_ingest_failed: {exc}")
        ingested = 0

    return IngestResponse(ingested=ingested, errors=errors)


@router.post("/sleep", response_model=IngestResponse)
def ingest_sleep_session(
    payload: SleepIngestRequest,
    db: Session = Depends(get_db),
) -> IngestResponse:
    try:
        has_updated_at = bool(
            db.execute(
                text(
                    """
                    SELECT EXISTS (
                        SELECT 1
                        FROM information_schema.columns
                        WHERE table_name = 'sleep_sessions'
                          AND column_name = 'updated_at'
                    )
                    """
                )
            ).scalar()
        )
        updated_at_assignment = ",\n                    updated_at = NOW()" if has_updated_at else ""
        db.execute(
            text(
                f"""
                INSERT INTO sleep_sessions (
                    user_id,
                    device_id,
                    start_time,
                    end_time,
                    sleep_score,
                    phases,
                    wake_count,
                    sleep_date
                )
                VALUES (
                    :user_id,
                    :device_id,
                    :start_time,
                    :end_time,
                    :sleep_score,
                    CAST(:phases AS jsonb),
                    :wake_count,
                    CAST(:sleep_date AS DATE)
                )
                ON CONFLICT (user_id, device_id, sleep_date) DO UPDATE SET
                    start_time = EXCLUDED.start_time,
                    end_time = EXCLUDED.end_time,
                    sleep_score = EXCLUDED.sleep_score,
                    phases = EXCLUDED.phases,
                    wake_count = EXCLUDED.wake_count{updated_at_assignment}
                """
            ),
            {
                "user_id": payload.user_id,
                "device_id": payload.db_device_id,
                "start_time": payload.start_time,
                "end_time": payload.end_time,
                "sleep_score": min(100, max(0, payload.score)),
                "phases": _json.dumps(payload.phases),
                "wake_count": payload.phases.get("awake", 30) // 30,
                "sleep_date": payload.date,
            },
        )
        db.commit()
        return IngestResponse(ingested=1, errors=[])
    except Exception as exc:
        db.rollback()
        return IngestResponse(ingested=0, errors=[str(exc)])
