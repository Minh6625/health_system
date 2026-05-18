from __future__ import annotations

import json as _json
import logging
import os
import time
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends, Header
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.adapters import (
    FallPersistenceAdapter,
    ImuPersistenceAdapter,
    RiskPersistenceAdapter,
    SleepRiskAdapter,
)
from app.core.dependencies import require_internal_service
from app.db.database import get_db
from app.models.device_model import Device
from app.models.relationship_model import UserRelationship
from app.models.sos_event_model import Alert, FallEvent
from app.schemas.fall_telemetry import ImuWindowRequest, ImuWindowResponse
from app.schemas.sleep_telemetry import SleepRiskRequest, SleepRiskResponse
from app.services.emergency_service import EmergencyService
from app.services.model_api_client import get_model_api_client
from app.services.push_notification_service import PushNotificationService
from app.services.risk_alert_service import calculate_device_risk, dispatch_risk_alerts
from app.services.settings_service import SettingsService

router = APIRouter(prefix="/telemetry", tags=["mobile-telemetry"])
logger = logging.getLogger(__name__)

# Post-fall monitoring window used to bypass risk-alert cooldown after SOS.
# Stored in the DB via FallEvent.sos_triggered_at so multi-worker deployments
# all see the same state (replaces the old in-process ``_post_fall_until`` dict).
_POST_FALL_WINDOW_SECONDS: int = 3600


def _is_in_post_fall_window(db: Session, device_id: int) -> bool:
    """Return True when a fall-triggered SOS occurred within the last hour for this device."""
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=_POST_FALL_WINDOW_SECONDS)
    return (
        db.query(FallEvent)
        .filter(
            FallEvent.device_id == device_id,
            FallEvent.sos_triggered.is_(True),
            FallEvent.sos_triggered_at >= cutoff,
        )
        .first()
    ) is not None


# Fall detection secondary-validation gate (P0). Confidence reported by the simulator
# / device must meet this threshold before the backend escalates to a full SOS event.
# Below threshold the FallEvent is still persisted for audit, plus a soft Alert row is
# created so caregivers can review without triggering the real-emergency takeover.
_DEFAULT_FALL_CONFIDENCE_THRESHOLD = 0.7


def _fall_confidence_threshold() -> float:
    raw = os.getenv("FALL_CONFIDENCE_THRESHOLD")
    if raw is None or not raw.strip():
        return _DEFAULT_FALL_CONFIDENCE_THRESHOLD
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return _DEFAULT_FALL_CONFIDENCE_THRESHOLD
    if value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


class VitalIngestVitals(BaseModel):
    # ADR-018 part 4 (Phase 7 S5): strict at the boundary. ``extra="forbid"``
    # blocks producers from smuggling unknown fields that the DB cannot
    # store; clinical ranges per
    # ``PM_REVIEW/REDESIGN_IOT_SIM_2026/03_data_contracts/vitals_ingest.md``
    # §1.3. All fields stay nullable — the per-item INSUFFICIENT_VITALS
    # gate (see ``ingest_vitals``) handles the "at least one critical
    # vital present" business rule.
    model_config = ConfigDict(extra="forbid")

    heart_rate: float | None = Field(default=None, ge=20, le=250)
    spo2: float | None = Field(default=None, ge=50, le=100)
    temperature: float | None = Field(default=None, ge=30, le=45)
    hrv: float | None = Field(default=None, ge=0, le=300)
    respiratory_rate: float | None = Field(default=None, ge=5, le=60)
    blood_pressure_sys: float | None = Field(default=None, ge=60, le=260)
    blood_pressure_dia: float | None = Field(default=None, ge=30, le=180)
    signal_quality: float | None = Field(default=None, ge=0.0, le=1.0)
    motion_artifact: bool | None = None


class VitalIngestItem(BaseModel):
    db_device_id: int
    emitted_at: datetime
    vitals: VitalIngestVitals


class VitalIngestRequest(BaseModel):
    # ADR-018 part 4 (Phase 7 S5): cap batch size at 50 per
    # ``vitals_ingest.md`` §1.3 so a buggy producer can't push a million
    # records through a single request and starve the worker.
    messages: list[VitalIngestItem] = Field(..., min_length=1, max_length=50)


class IngestResponse(BaseModel):
    """Legacy response model — kept for the alert + sleep endpoints.

    ``ingest_vitals`` returns :class:`VitalIngestResponse` instead so the
    structured per-item error contract + auto-trigger summary do not
    leak into ``/telemetry/alert`` and ``/telemetry/sleep``.
    """

    ingested: int
    errors: list[str] = Field(default_factory=list)


class IngestError(BaseModel):
    """Per-item rejection record for the vitals batch endpoint.

    Pinned by ``vitals_ingest.md`` §2.1: producers iterate the
    ``errors`` array and retry per-item with the corrected payload
    instead of re-pushing the whole batch.
    """

    index: int
    device_id: int
    emitted_at: datetime
    error_code: str
    message: str


class VitalIngestResponse(BaseModel):
    """ADR-018 part 4 response shape for ``/telemetry/ingest``.

    ``ingested`` + ``rejected`` always sum to ``len(messages)``.
    ``errors`` is per-item and only populated for the rejected slice.
    ``risk_evaluated_devices`` is the unique set of ``device_id``
    values the post-ingest auto-trigger fanned out to, so producers can
    correlate which devices the mobile app will receive a fresh risk
    push for.
    """

    ingested: int = 0
    rejected: int = 0
    errors: list[IngestError] = Field(default_factory=list)
    risk_evaluated_devices: list[int] = Field(default_factory=list)


# ADR-018 part 4 (Phase 7 S5): in-memory idempotency cache for the
# ``/telemetry/ingest`` endpoint. Producers (IoT sim, mobile bridge)
# attach ``Idempotency-Key`` to every batch; a retry within
# :data:`_IDEMPOTENCY_TTL_SECONDS` returns the original response so a
# flaky network retry never double-counts vitals.
#
# Trade-off accepted: per-process dict means a multi-replica deploy
# could still double-write across replicas. The single-replica dev
# topology (one uvicorn worker) is the only target right now; upgrading
# to Redis is tracked as a follow-up under ADR-020 part 2.
_IDEMPOTENCY_TTL_SECONDS: int = 5 * 60
_IDEMPOTENCY_CACHE: dict[str, tuple[float, "VitalIngestResponse"]] = {}


def _idempotency_lookup(key: str | None) -> "VitalIngestResponse | None":
    """Return the cached response for ``key`` if still within the TTL.

    Returns ``None`` when the key is absent, missing from the cache, or
    expired. Side-effect: expired entries are pruned on access so the
    dict cannot grow without bound under steady producer traffic.

    Defensive ``isinstance`` check — when ``ingest_vitals`` is called
    directly (e.g. from unit tests) FastAPI's ``Header(default=None,
    alias=...)`` parameter declaration leaks through as the actual
    argument value instead of ``None``. Treat any non-string value as
    "no key supplied" so direct invocations stay deterministic.
    """
    if not isinstance(key, str) or not key:
        return None
    now = time.monotonic()
    expired = [
        k for k, (ts, _) in _IDEMPOTENCY_CACHE.items()
        if now - ts > _IDEMPOTENCY_TTL_SECONDS
    ]
    for k in expired:
        _IDEMPOTENCY_CACHE.pop(k, None)
    entry = _IDEMPOTENCY_CACHE.get(key)
    return entry[1] if entry else None


def _idempotency_store(key: str | None, response: "VitalIngestResponse") -> None:
    if not isinstance(key, str) or not key:
        return
    _IDEMPOTENCY_CACHE[key] = (time.monotonic(), response)


def _idempotency_clear_for_tests() -> None:
    """Test-only — reset the cache between parametrised cases.

    Not exposed via the public API; tests import it directly off the
    module so each scenario starts with a known-empty cache.
    """
    _IDEMPOTENCY_CACHE.clear()


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
    """Map IoT sim outbound severity to canonical DB vocab per ADR-015.

    Layer 2 (IoT outbound) -> Layer 4 (DB canonical):
      normal  -> low
      warning -> high
      critical -> critical
      high    -> high
      (other) -> low
    """
    normalized = (severity or "").strip().lower()
    if normalized == "normal":
        return "low"
    if normalized == "warning":
        return "high"
    if normalized == "critical":
        return "critical"
    if normalized == "high":
        return "high"
    if normalized == "medium":
        return "medium"
    return "low"


def _map_alert_type(event_type: str) -> str:
    normalized = (event_type or "").strip().lower()
    if normalized == "fall_detected":
        return "fall_detection"
    if normalized == "vitals_out_of_range":
        return "vitals_threshold"
    return normalized or "generic_alert"


def _map_telemetry_risk_level(severity: str) -> str | None:
    normalized = (severity or "").strip().lower()
    if normalized in {"warning", "high", "medium"}:
        return "medium"
    if normalized == "critical":
        return "critical"
    return None


def _build_alert_title(event_type: str, severity: str) -> str:
    normalized = (event_type or "").strip().lower()
    if normalized == "fall_detected":
        return "Fall detected"
    if severity == "critical":
        return "Critical vital signs detected"
    if severity == "high":
        return "Warning vital signs detected"
    return normalized.replace("_", " ").strip().title() or "Telemetry alert"


@router.post(
    "/ingest",
    response_model=VitalIngestResponse,
    dependencies=[Depends(require_internal_service)],
)
def ingest_vitals(
    payload: VitalIngestRequest,
    db: Session = Depends(get_db),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> VitalIngestResponse:
    # ADR-018 part 4 (Phase 7 S5): idempotency replay short-circuit —
    # producers retry on a transient network error and we MUST return
    # the original response shape so they do not double-count.
    cached = _idempotency_lookup(idempotency_key)
    if cached is not None:
        return cached

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
    rejected = 0
    errors: list[IngestError] = []
    # Track which devices actually got a fresh row this batch so the
    # post-commit auto-trigger only fans out for them (rejected items
    # must NOT pull the model-api into a synthetic-only inference).
    inserted_device_ids: list[int] = []

    for index, message in enumerate(payload.messages):
        vitals = message.vitals

        # ADR-018 part 4 / HS-024 fix at the boundary: refuse vitals
        # records where BOTH critical fields are NULL. Soft fields
        # (BP, HRV, temp...) may still be NULL — the downstream
        # ``_build_inference_payload`` handles default-or-fail for
        # those separately.
        if vitals.heart_rate is None and vitals.spo2 is None:
            rejected += 1
            errors.append(
                IngestError(
                    index=index,
                    device_id=message.db_device_id,
                    emitted_at=message.emitted_at,
                    error_code="INSUFFICIENT_VITALS",
                    message=(
                        "cần ít nhất 1 trong heart_rate hoặc spo2 để "
                        "INSERT vitals; record bị từ chối ở boundary."
                    ),
                )
            )
            continue

        params = {
            "time": message.emitted_at,
            "device_id": message.db_device_id,
            "heart_rate": vitals.heart_rate,
            "spo2": vitals.spo2,
            "temperature": vitals.temperature,
            "hrv": vitals.hrv,
            "respiratory_rate": vitals.respiratory_rate,
            "blood_pressure_sys": (
                int(round(vitals.blood_pressure_sys))
                if vitals.blood_pressure_sys is not None
                else None
            ),
            "blood_pressure_dia": (
                int(round(vitals.blood_pressure_dia))
                if vitals.blood_pressure_dia is not None
                else None
            ),
            "signal_quality": vitals.signal_quality,
            "motion_artifact": vitals.motion_artifact,
        }

        try:
            with db.begin_nested():
                result = db.execute(insert_sql, params)
            inserted_count = max(result.rowcount or 0, 0)
            ingested += inserted_count
            if inserted_count > 0:
                inserted_device_ids.append(message.db_device_id)
        except Exception as exc:
            rejected += 1
            errors.append(
                IngestError(
                    index=index,
                    device_id=message.db_device_id,
                    emitted_at=message.emitted_at,
                    error_code="INSERT_FAILED",
                    message=str(exc),
                )
            )

    risk_evaluated_devices: list[int] = []
    try:
        db.commit()

        if ingested > 0:
            # Preserve first-seen order so the response is deterministic
            # for producer-side assertions in integration tests.
            unique_devices: list[int] = []
            seen: set[int] = set()
            for device_id in inserted_device_ids:
                if device_id not in seen:
                    seen.add(device_id)
                    unique_devices.append(device_id)

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
                    {"device_ids": unique_devices},
                )
                db.commit()
            except Exception as sync_exc:
                db.rollback()
                errors.append(
                    IngestError(
                        index=-1,
                        device_id=0,
                        emitted_at=datetime.now(timezone.utc),
                        error_code="LAST_SYNC_UPDATE_FAILED",
                        message=str(sync_exc),
                    )
                )

            for device_id in unique_devices:
                try:
                    resolved_user_id = _resolve_alert_user_id(
                        db,
                        db_device_id=device_id,
                        explicit_user_id=None,
                    )
                    if resolved_user_id is None:
                        logger.warning(
                            "Telemetry risk evaluation skipped: device=%s has no assigned user",
                            device_id,
                        )
                        continue

                    calculate_device_risk(
                        db,
                        device_id=int(device_id),
                        user_id=int(resolved_user_id),
                        allow_cached=True,
                        dispatch_alerts=True,
                    )
                    risk_evaluated_devices.append(int(device_id))
                except Exception as exc:
                    logger.exception(
                        "Telemetry risk evaluation failed after ingest for device %s",
                        device_id,
                    )
                    errors.append(
                        IngestError(
                            index=-1,
                            device_id=int(device_id),
                            emitted_at=datetime.now(timezone.utc),
                            error_code="RISK_EVAL_FAILED",
                            message=str(exc),
                        )
                    )
    except Exception as exc:
        db.rollback()
        ingested = 0
        errors.append(
            IngestError(
                index=-1,
                device_id=0,
                emitted_at=datetime.now(timezone.utc),
                error_code="COMMIT_FAILED",
                message=str(exc),
            )
        )

    response = VitalIngestResponse(
        ingested=ingested,
        rejected=rejected,
        errors=errors,
        risk_evaluated_devices=risk_evaluated_devices,
    )
    _idempotency_store(idempotency_key, response)
    return response


@router.post("/alert", response_model=IngestResponse, dependencies=[Depends(require_internal_service)])
def ingest_alert(
    payload: AlertIngestRequest,
    background_tasks: BackgroundTasks,
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
            confidence_value = _pick_float(metadata, "confidence") or 0.0
            fall_event = FallEvent(
                device_id=payload.db_device_id,
                detected_at=payload.timestamp,
                confidence=confidence_value,
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

            threshold = _fall_confidence_threshold()
            if confidence_value < threshold:
                # Secondary-validation gate: low-confidence fall stays as soft Alert,
                # caregivers can review via notifications list without full SOS takeover.
                logger.warning(
                    "Fall event below confidence threshold: device=%s confidence=%.3f threshold=%.3f -> soft alert (no SOS)",
                    payload.db_device_id,
                    confidence_value,
                    threshold,
                )
                soft_details = dict(metadata)
                soft_details.update(
                    {
                        "confidence": confidence_value,
                        "fall_confidence_threshold": threshold,
                        "secondary_validation": "pending_low_confidence",
                    }
                )
                soft_alert = Alert(
                    device_id=payload.db_device_id,
                    user_id=resolved_user_id,
                    fall_event_id=fall_event_id,
                    alert_type="fall_detection",
                    severity="high",
                    title="Phát hiện khả năng té ngã (chờ xác minh)",
                    message=(
                        "Phát hiện chuyển động giống té ngã "
                        f"(độ tin cậy {confidence_value:.0%}, dưới ngưỡng {threshold:.0%}). "
                        "Vui lòng xác nhận trước khi kích hoạt SOS."
                    ),
                    details=soft_details,
                )
                db.add(soft_alert)
                db.commit()
                ingested += 1
                return IngestResponse(ingested=ingested, errors=errors)

            if resolved_user_id is not None:
                EmergencyService.trigger_sos(
                    db=db,
                    user_id=resolved_user_id,
                    trigger_type="auto",
                    latitude=_pick_float(metadata, "latitude"),
                    longitude=_pick_float(metadata, "longitude"),
                    address=_pick_value(metadata, "address"),
                    fall_event_id=fall_event_id,
                    send_push=True,
                )
                # Flip the parent FallEvent's escalation flags so
                # ``derive_status`` projects ``status='escalated'`` for
                # the mobile UI.  Without this, the SOSEvent row is
                # created with ``fall_event_id`` set but the parent
                # row's ``sos_triggered`` stays False forever, leaving
                # the fall card stuck on "detected".
                fall_event.sos_triggered = True
                fall_event.sos_triggered_at = datetime.now(timezone.utc)
                db.commit()

                # Post-fall risk snapshot: evaluate vitals immediately after
                # confirmed fall so caregivers get an up-to-date risk score
                # alongside the SOS notification. Non-fatal — a failure here
                # must never block the SOS push that follows.
                try:
                    calculate_device_risk(
                        db,
                        device_id=int(payload.db_device_id),
                        user_id=int(resolved_user_id),
                        allow_cached=False,
                        dispatch_alerts=False,
                    )
                except Exception:  # noqa: BLE001
                    logger.exception(
                        "Post-fall risk calculation failed for device %s (non-fatal)",
                        payload.db_device_id,
                    )

                # ADR-023 Phase 7 S13: fan-out fall critical push to the
                # patient + their caregivers.  Patient gets the full-screen
                # FallAlertScreen takeover; caregivers get a banner-only
                # notification (mobile differentiates via is_recipient_patient
                # flag).  Caregiver SOS push still fires through trigger_sos
                # above — this is a separate, fall-specific push so the
                # family banner copy is distinct ("member may have fallen")
                # from the generic SOS copy.
                _patient_id = int(resolved_user_id)
                try:
                    _caregiver_ids = [
                        int(row.caregiver_id)
                        for row in db.query(UserRelationship.caregiver_id).filter(
                            UserRelationship.patient_id == _patient_id,
                            UserRelationship.status == "accepted",
                            UserRelationship.can_receive_alerts.is_(True),
                            UserRelationship.deleted_at.is_(None),
                        ).all()
                    ]
                except Exception:
                    logger.warning(
                        "Failed to query caregivers for fall fanout patient=%s (non-fatal)",
                        _patient_id,
                        exc_info=True,
                    )
                    _caregiver_ids = []
                _all_recipients = [_patient_id] + _caregiver_ids
                background_tasks.add_task(
                    PushNotificationService.send_fall_critical_alert,
                    db,
                    recipient_user_ids=_all_recipients,
                    patient_user_id=_patient_id,
                    fall_event_id=int(fall_event_id),
                    fall_event_uuid=str(fall_event.uuid),
                    title="Phát hiện té ngã",
                    body=(
                        "Hệ thống phát hiện bạn có thể đã té ngã. "
                        "Nhấn 'Tôi ổn' nếu bạn vẫn ổn."
                    ),
                    confidence=float(confidence_value),
                )
                logger.info(
                    "Fall fanout queued: patient=%s caregivers=%s fall_event_id=%s",
                    _patient_id, _caregiver_ids, fall_event_id,
                )

                ingested += 1
                return IngestResponse(ingested=ingested, errors=errors)

        telemetry_risk_level = _map_telemetry_risk_level(payload.severity)
        if payload.event_type == "vitals_out_of_range" and telemetry_risk_level:
            if resolved_user_id is None:
                raise ValueError(
                    f"risk telemetry alert missing user binding for device {payload.db_device_id}"
                )

            risk_result = None
            try:
                risk_result = calculate_device_risk(
                    db,
                    device_id=int(payload.db_device_id),
                    user_id=int(resolved_user_id),
                    allow_cached=False,
                    dispatch_alerts=False,
                )
            except Exception:
                logger.exception(
                    "Telemetry alert could not create linked risk score for device %s",
                    payload.db_device_id,
                )

            _in_post_fall = _is_in_post_fall_window(db, int(payload.db_device_id))
            dispatch_risk_alerts(
                db,
                device_id=int(payload.db_device_id),
                user_id=int(resolved_user_id),
                risk_level=telemetry_risk_level,
                score=(
                    risk_result.score
                    if risk_result is not None
                    else (_pick_float(metadata, "risk_score", "score", "confidence") or 0.0)
                ),
                risk_score_id=(
                    risk_result.risk_score_id
                    if risk_result is not None
                    else _pick_int(metadata, "risk_score_id")
                ),
                post_fall=_in_post_fall,
            )
            ingested += 1
            return IngestResponse(ingested=ingested, errors=errors)

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


@router.post("/sleep", response_model=IngestResponse, dependencies=[Depends(require_internal_service)])
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


# ---------------------------------------------------------------------------
# Phase 4B-thin — raw IMU window ingest
# ---------------------------------------------------------------------------


@router.post("/imu-window", response_model=ImuWindowResponse, dependencies=[Depends(require_internal_service)])
def ingest_imu_window(
    payload: ImuWindowRequest,
    db: Session = Depends(get_db),
) -> ImuWindowResponse:
    """Ingest a raw IMU window, run model-api fall inference, persist on success.

    Phase 4B-thin (see ``backend/docs/risk-contract-baseline.md`` §7e):

    1. The mobile / simulator client posts a SensorSample window.
    2. Backend forwards it to ``ModelApiClient.predict_fall`` (which is
       breaker-wrapped + timed by Phase 7).
    3. On a successful prediction, ``FallPersistenceAdapter.persist``
       writes one ``fall_events`` row and the response carries the new
       ``fall_event_id`` so the caller can later POST
       ``/api/v1/mobile/telemetry/alert`` with that id for SOS escalation.
    4. On breaker-open / network failure / 5xx (anything that makes
       ``predict_fall`` return ``None``), **no row is written**. Falsely
       claiming "no fall" is dangerous (false-negative on a real fall)
       and falsely claiming "fall" is dangerous too (alarm fatigue), so
       we surface ``status="model_unavailable"`` and let the caller
       decide whether to retry. Existing rule-based fallback paths in
       ``risk_alert_service`` are deliberately **not** invoked for fall:
       the plan flags fall as alert-state, not insight-state, and a
       rule-based fall predictor would need its own confusion-matrix
       harness (Phase 4B-full).
    """
    # Build the upstream payload in the model-api shape, dropping our
    # internal ``db_device_id``. The model-api uses a string device id;
    # we send the DB id for log correlation back to the same row.
    model_payload: dict[str, Any] = {
        "device_id": str(payload.db_device_id),
        "sampling_rate": payload.sampling_rate,
        "window_size": payload.window_size,
        "data": [sample.model_dump() for sample in payload.data],
    }

    prediction = get_model_api_client().predict_fall(model_payload)
    if prediction is None:
        # Breaker open / transport error / non-200 / malformed body.
        # Logged inside ModelApiClient already; we just surface the
        # outcome to the caller without persisting a row.
        return ImuWindowResponse(status="model_unavailable")

    fall_event = FallPersistenceAdapter.persist(
        db,
        db_device_id=payload.db_device_id,
        prediction=prediction,
    )

    fall_probability = FallPersistenceAdapter._extract_probability(prediction)
    band = str(
        (prediction.get("prediction") or {}).get("prediction_band")
        or prediction.get("predicted_fall_label")
        or prediction.get("risk_level")
        or "unknown"
    )
    requires_attention = bool(prediction.get("requires_attention", False))
    predicted_fall = bool(prediction.get("predicted_fall", False))
    meta = prediction.get("meta") if isinstance(prediction.get("meta"), dict) else {}
    raw_request_id = meta.get("request_id") if isinstance(meta, dict) else None
    model_request_id: str | None = None
    if raw_request_id is not None:
        candidate = str(raw_request_id).strip()
        model_request_id = candidate[:36] if candidate else None

    # ADR-022 Phase 7 S8: persist the raw IMU window for replay + retrain.
    # We write the window AFTER the fall row so we can populate
    # ``imu_windows.fall_event_id`` in a single INSERT instead of two
    # statements, then back-link the surrogate id + time onto
    # ``fall_events.imu_window_id`` / ``imu_window_time``. The composite
    # FK on ``fall_events`` is enforced by the migration — both columns
    # MUST be written together. A persistence failure on this step is
    # surfaced as 500 by :class:`ImuPersistenceAdapter` and the fall row
    # remains in place: missing raw evidence is not a reason to drop the
    # event itself.
    imu_window = ImuPersistenceAdapter.persist(
        db,
        db_device_id=payload.db_device_id,
        payload=payload,
        fall_event_id=fall_event.id,
        model_request_id=model_request_id,
    )
    try:
        fall_event.imu_window_id = imu_window.id
        fall_event.imu_window_time = imu_window.time
        db.commit()
        db.refresh(fall_event)
    except Exception:
        db.rollback()
        logger.exception(
            "Failed to back-link fall_event %s to imu_window %s",
            fall_event.id,
            imu_window.id,
        )
        # The window is already on disk; leaving the back-link null is
        # acceptable (the link table can be reconstructed by joining on
        # device_id + time window). Continue with the success response.

    return ImuWindowResponse(
        status="ok",
        fall_event_id=fall_event.id,
        fall_probability=fall_probability,
        prediction_band=band,
        predicted_fall=predicted_fall,
        requires_attention=requires_attention,
        model_request_id=model_request_id,
    )


# ---------------------------------------------------------------------------
# Phase 4A-thin — sleep risk ingest
# ---------------------------------------------------------------------------


@router.post("/sleep-risk", response_model=SleepRiskResponse, dependencies=[Depends(require_internal_service)])
def ingest_sleep_risk(
    payload: SleepRiskRequest,
    db: Session = Depends(get_db),
) -> SleepRiskResponse:
    """Ingest a canonical sleep session, run model-api inference, persist on success.

    Phase 4A-thin (see ``backend/docs/risk-contract-baseline.md`` §7f):

    1. The mobile / simulator client posts a ``SleepRecord`` (verbatim
       model-api shape) plus ``db_device_id`` + ``db_user_id``.
    2. Backend forwards to ``ModelApiClient.predict_sleep`` (already
       breaker-wrapped + StageTimer-instrumented by Phase 7 + 4A-thin).
    3. ``SleepRiskAdapter.from_response`` projects the result into a
       :class:`NormalizedExplanation`, **inverting the score** so a
       sleep_score of 85 (good sleep) lands as risk_score 15 in the
       ``risk_scores`` table — same axis convention as vitals risk rows.
    4. ``RiskPersistenceAdapter.persist`` writes the row with
       ``risk_type='sleep'`` (allowed by the migration in
       ``backend/migrations/20260427_sleep_risk_type.sql``).
    5. ``model_unavailable`` semantics mirror the IMU window route — no
       row is written when ``predict_sleep`` returns ``None`` (breaker
       open / transport / 5xx / malformed body); sleep risk is not
       worth guessing at when the model is down.
    """
    # Inner record is already in the model-api shape — just dump it.
    record_dict = SleepRiskAdapter.to_record(payload.record.model_dump())

    prediction = get_model_api_client().predict_sleep(record_dict)
    if prediction is None:
        return SleepRiskResponse(status="model_unavailable")

    inference = SleepRiskAdapter.from_response(
        prediction,
        sleep_record=record_dict,
    )

    # Sleep is not a point-in-time vitals snapshot, so vitals_row /
    # feature_snapshot are empty. The interesting payload (top_features,
    # ai_explanation, request_id) all lands via NormalizedExplanation.
    risk_score_row = RiskPersistenceAdapter.persist(
        db,
        user_id=int(payload.db_user_id),
        device_id=int(payload.db_device_id),
        inference=inference,
        vitals_row={},
        feature_snapshot={},
        defaults_applied=[],
        risk_type="sleep",
    )

    predicted_sleep_score = SleepRiskAdapter._extract_sleep_score(prediction)

    return SleepRiskResponse(
        status="ok",
        risk_score_id=risk_score_row.id,
        risk_score=inference.risk_score,
        risk_level=inference.risk_level,
        predicted_sleep_score=predicted_sleep_score,
        model_request_id=inference.model_request_id,
    )
