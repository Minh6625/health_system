from __future__ import annotations

import json as _json
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, BackgroundTasks, Depends
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.adapters import (
    FallPersistenceAdapter,
    RiskPersistenceAdapter,
    SleepRiskAdapter,
)
from app.core.dependencies import require_internal_service
from app.db.database import get_db
from app.models.device_model import Device
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


@router.post("/ingest", response_model=IngestResponse, dependencies=[Depends(require_internal_service)])
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

            for device_id in pushed_device_ids:
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
                except Exception as exc:
                    logger.exception(
                        "Telemetry risk evaluation failed after ingest for device %s",
                        device_id,
                    )
                    errors.append(
                        f"risk_eval_failed device_id={device_id}: {exc}"
                    )
    except Exception as exc:
        db.rollback()
        ingested = 0
        errors.append(f"commit_failed: {exc}")

    return IngestResponse(ingested=ingested, errors=errors)


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

                # Module FA-2 patient-facing push.  ``trigger_sos`` only
                # pushes SOS notifications to *caregivers*; the patient
                # device receives nothing through that path.  We fire a
                # dedicated ``fall_critical`` data-only push to the
                # patient so their phone shows the full-screen FallAlert
                # takeover with sound + vibration + 30s countdown.  If
                # FCM creds are absent or the patient has no active
                # push token the helper logs + returns silently — never
                # raises — so a missing push does not block the SOS
                # escalation we already committed above.
                background_tasks.add_task(
                    PushNotificationService.send_fall_critical_alert,
                    db,
                    recipient_user_ids=[int(resolved_user_id)],
                    fall_event_id=int(fall_event_id),
                    fall_event_uuid=str(fall_event.uuid),
                    title="Phát hiện té ngã",
                    body=(
                        "Hệ thống phát hiện bạn có thể đã té ngã. "
                        "Nhấn 'Tôi ổn' nếu bạn vẫn ổn."
                    ),
                    confidence=float(confidence_value),
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


# ---------------------------------------------------------------------------
# Phase 4B-thin — raw IMU window ingest
# ---------------------------------------------------------------------------


@router.post("/imu-window", response_model=ImuWindowResponse)
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
       ``/mobile/telemetry/alert`` with that id for SOS escalation.
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


@router.post("/sleep-risk", response_model=SleepRiskResponse)
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
