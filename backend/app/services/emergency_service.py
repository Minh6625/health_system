import logging
from typing import Any, Optional, List
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.repositories.emergency_repository import EmergencyRepository
from app.models.sos_event_model import Alert, SOSEvent
from app.services.push_notification_service import PushNotificationService
from app.utils.audit_helper import safe_log_action
from app.schemas.emergency import (
    SOSAlertsResponse,
    SOSEventListItem,
    SOSEventResponse,
    PatientInfo,
    LocationInfo,
    FallDetectionXAI,
    TimelineEvent,
    ResolutionInfo,
)

logger = logging.getLogger(__name__)

SOS_DEDUP_WINDOW_SECONDS: int = 60


class EmergencyService:
    """Business logic for emergency/SOS operations."""

    @staticmethod
    def _normalize_read_trigger_type(
        stored_trigger_type: str | None,
        *,
        is_risk_origin: bool,
    ) -> str:
        if is_risk_origin:
            return "vital_critical"

        normalized = (stored_trigger_type or "").strip().lower()
        if normalized in {"auto", "fall_detected", "fall_detection"}:
            return "fall_detected"
        if normalized == "manual":
            return "manual"
        return normalized or "manual"

    @staticmethod
    def _parse_resolution_notes(
        raw_notes: str | None,
    ) -> tuple[str, str | None]:
        default_status = "safe"
        if raw_notes is None:
            return default_status, None

        normalized = raw_notes.strip()
        if not normalized:
            return default_status, None

        if normalized.startswith("[") and "]" in normalized:
            closing_index = normalized.find("]")
            status_value = normalized[1:closing_index].strip().lower() or default_status
            cleaned_notes = normalized[closing_index + 1 :].strip()
            if not cleaned_notes or cleaned_notes.lower() == "no notes":
                cleaned_notes = None
            return status_value, cleaned_notes

        return default_status, normalized

    @staticmethod
    def trigger_sos(
        db: Session,
        user_id: int,
        trigger_type: str = "manual",
        device_id: Optional[int] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        address: Optional[str] = None,
        fall_event_id: Optional[int] = None,
        *,
        commit: bool = True,
        send_push: bool = True,
    ) -> tuple[SOSEvent, dict[str, Any]]:
        """Trigger a new SOS event and fan out alerts."""

        cutoff = datetime.now(timezone.utc) - timedelta(seconds=SOS_DEDUP_WINDOW_SECONDS)
        existing = (
            db.query(SOSEvent)
            .filter(
                SOSEvent.user_id == int(user_id),
                SOSEvent.status == "active",
                SOSEvent.triggered_at >= cutoff,
            )
            .first()
        )
        if existing is not None:
            logger.warning(
                "SOS dedup: active SOS %s already exists for user %s within %ds window — skipping",
                existing.id,
                user_id,
                SOS_DEDUP_WINDOW_SECONDS,
            )
            return existing, {
                "recipient_user_ids": [],
                "title": "",
                "body": "",
                "alert_type": "",
                "trigger_type": trigger_type,
                "notification_id_by_user": {},
                "recipient_count": 0,
                "skipped": True,
            }

        resolved_device_id = device_id
        if resolved_device_id is None:
            resolved_device_id = EmergencyRepository.get_active_device_id_for_user(
                db,
                int(user_id),
            )

        if resolved_device_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Không tìm thấy thiết bị hoạt động để gửi SOS",
            )

        sos_event = EmergencyRepository.create_sos_event(
            db=db,
            user_id=user_id,
            device_id=resolved_device_id,
            trigger_type=trigger_type,
            latitude=latitude,
            longitude=longitude,
            address=address,
            fall_event_id=fall_event_id,
            commit=commit,
        )

        dispatch_info = EmergencyService._create_alerts_for_sos_event(
            db,
            sos_event,
            commit=commit,
            send_push=send_push,
        )
        return sos_event, dispatch_info

    @staticmethod
    def _create_alerts_for_sos_event(
        db: Session,
        sos_event: SOSEvent,
        *,
        commit: bool = True,
        send_push: bool = True,
    ) -> dict[str, Any]:
        """Fan out SOS/fall alerts to patient and linked caregivers."""
        patient = EmergencyRepository.get_user_by_id(db, sos_event.user_id)
        patient_name = patient.full_name if patient else f"User #{sos_event.user_id}"

        normalized_trigger = (sos_event.trigger_type or "").strip().lower()
        is_fall = normalized_trigger in {"auto", "fall_detected", "fall_detection"}

        alert_type = "fall_detected" if is_fall else "sos"
        title = (
            f"Phát hiện té ngã: {patient_name}"
            if is_fall
            else f"Cảnh báo SOS: {patient_name}"
        )
        message = (
            "Phát hiện té ngã tự động. Cần kiểm tra ngay."
            if is_fall
            else "Người dùng đã kích hoạt SOS thủ công. Cần hỗ trợ ngay."
        )

        # Bug fix G-3: location is now stamped per-recipient based on each
        # caregiver's ``can_view_location`` flag. The shared metadata stays in
        # ``base_details``; the optional location fields are merged in below
        # only for caregivers that still hold the location permission.
        base_details: dict[str, Any] = {
            "sos_id": sos_event.id,
            "sos_event_id": sos_event.id,
            "trigger_type": sos_event.trigger_type,
            "patient_user_id": sos_event.user_id,
            "patient_name": patient_name,
        }
        location_payload: dict[str, Any] = {
            "address": sos_event.address,
            "latitude": float(sos_event.latitude)
            if sos_event.latitude is not None
            else None,
            "longitude": float(sos_event.longitude)
            if sos_event.longitude is not None
            else None,
        }

        recipients_with_perms = (
            EmergencyRepository.get_sos_alert_recipients_with_permissions(
                db,
                sos_event.user_id,
            )
        )
        recipient_user_ids = [cid for cid, _ in recipients_with_perms]

        created_alerts: list[Alert] = []
        for recipient_user_id, can_view_location in recipients_with_perms:
            recipient_details = {
                **base_details,
                "recipient_user_id": recipient_user_id,
            }
            if can_view_location:
                recipient_details.update(location_payload)
            alert = Alert(
                device_id=sos_event.device_id,
                user_id=recipient_user_id,
                fall_event_id=sos_event.fall_event_id,
                alert_type=alert_type,
                severity="critical",
                title=title,
                message=message,
                details=recipient_details,
            )
            db.add(alert)
            created_alerts.append(alert)

        db.flush()

        notification_id_by_user = {
            int(alert.user_id): int(alert.id)
            for alert in created_alerts
            if alert.user_id is not None and alert.id is not None
        }

        if commit:
            db.commit()
        if send_push:
            PushNotificationService.send_sos_push_alerts(
                db,
                recipient_user_ids=recipient_user_ids,
                title=title,
                body=message,
                sos_id=int(sos_event.id),
                alert_type=alert_type,
                trigger_type=sos_event.trigger_type,
                notification_id_by_user=notification_id_by_user,
            )

        return {
            "recipient_user_ids": recipient_user_ids,
            "title": title,
            "body": message,
            "alert_type": alert_type,
            "trigger_type": sos_event.trigger_type,
            "notification_id_by_user": notification_id_by_user,
            "recipient_count": len(recipient_user_ids),
        }

    @staticmethod
    def respond_to_risk_alert(
        db: Session,
        *,
        current_user_id: int,
        notification_id: int,
        response_action: str,
        risk_score_id: Optional[int] = None,
        source: str,
        device_id: Optional[int] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        address: Optional[str] = None,
        notes: Optional[str] = None,
        background_tasks: Optional[Any] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> dict[str, Any]:
        """Handle a terminal response for an initial risk alert."""
        alert = EmergencyRepository.get_alert_by_id(db, notification_id)
        if alert is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy cảnh báo rủi ro",
            )

        if alert.user_id is None or int(alert.user_id) != int(current_user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Không có quyền phản hồi cảnh báo này",
            )

        if alert.alert_type not in {"risk_high", "risk_critical"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cảnh báo này không hỗ trợ phản hồi rủi ro",
            )

        existing_response = EmergencyRepository.get_risk_alert_response(db, notification_id)
        if existing_response is not None:
            return {
                "success": True,
                "status": "duplicate",
                "acknowledged_at": existing_response.responded_at,
                "sos_event_id": existing_response.sos_event_id,
            }

        normalized_action = response_action.strip().lower()
        if normalized_action not in {"safe", "help_requested", "timeout_escalated"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Hành động phản hồi không hợp lệ",
            )

        if source not in {"overlay", "push_tap"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nguồn phản hồi không hợp lệ",
            )

        alert_details = alert.details if isinstance(alert.details, dict) else {}
        expected_risk_score_id = alert_details.get("risk_score_id")
        if risk_score_id is not None and expected_risk_score_id is not None:
            try:
                if int(risk_score_id) != int(expected_risk_score_id):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Risk score không khớp với cảnh báo",
                    )
            except (TypeError, ValueError):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Risk score không hợp lệ",
                )

        response_row = EmergencyRepository.create_risk_alert_response(
            db,
            notification_id=notification_id,
            response_action=normalized_action,
            source=source,
            risk_score_id=risk_score_id,
            device_id=device_id,
            latitude=latitude,
            longitude=longitude,
            address=address,
        )

        try:
            if normalized_action == "safe":
                db.commit()
                safe_log_action(
                    db,
                    action="risk_alert.acknowledged",
                    status="success",
                    user_id=int(current_user_id),
                    resource_type="alert",
                    resource_id=int(notification_id),
                    ip_address=ip_address,
                    user_agent=user_agent,
                    details={
                        "source": source,
                        "response_action": normalized_action,
                        "risk_score_id": risk_score_id,
                    },
                )
                return {
                    "success": True,
                    "status": "acknowledged",
                    "acknowledged_at": response_row.responded_at,
                    "sos_event_id": None,
                }

            trigger_type = "manual" if normalized_action == "help_requested" else "auto"
            sos_event, dispatch_info = EmergencyService.trigger_sos(
                db,
                user_id=int(current_user_id),
                trigger_type=trigger_type,
                device_id=device_id or alert.device_id,
                latitude=latitude,
                longitude=longitude,
                address=address,
                commit=False,
                send_push=False,
            )
            response_row.sos_event_id = int(sos_event.id)
            db.commit()

            # Audit: log BOTH the risk-alert escalation and the resulting
            # SOS creation so the timeline reads correctly even when the
            # SOS was triggered by an alert response (rather than the
            # direct ``POST /emergency/sos/trigger`` route).
            _audit_details = {
                "source": source,
                "response_action": normalized_action,
                "trigger_type": trigger_type,
                "risk_score_id": risk_score_id,
                "recipient_count": len(dispatch_info["recipient_user_ids"]),
                "has_location": latitude is not None,
            }
            safe_log_action(
                db,
                action="risk_alert.escalated",
                status="success",
                user_id=int(current_user_id),
                resource_type="alert",
                resource_id=int(notification_id),
                ip_address=ip_address,
                user_agent=user_agent,
                details={**_audit_details, "sos_event_id": int(sos_event.id)},
            )
            safe_log_action(
                db,
                action="sos.triggered",
                status="success",
                user_id=int(current_user_id),
                resource_type="sos_event",
                resource_id=int(sos_event.id),
                ip_address=ip_address,
                user_agent=user_agent,
                details={**_audit_details, "origin": "risk_alert"},
            )

            _push_kwargs = dict(
                recipient_user_ids=dispatch_info["recipient_user_ids"],
                title=dispatch_info["title"],
                body=dispatch_info["body"],
                sos_id=int(sos_event.id),
                alert_type=dispatch_info["alert_type"],
                trigger_type=dispatch_info["trigger_type"],
                notification_id_by_user=dispatch_info["notification_id_by_user"],
            )
            if background_tasks is not None:
                background_tasks.add_task(
                    PushNotificationService.send_sos_push_alerts, db, **_push_kwargs
                )
            else:
                PushNotificationService.send_sos_push_alerts(db, **_push_kwargs)

            return {
                "success": True,
                "status": "escalated",
                "acknowledged_at": response_row.responded_at,
                "sos_event_id": response_row.sos_event_id,
                "recipient_count": len(dispatch_info["recipient_user_ids"]),
            }
        except IntegrityError:
            db.rollback()
            existing_response = EmergencyRepository.get_risk_alert_response(db, notification_id)
            if existing_response is None:
                raise
            return {
                "success": True,
                "status": "duplicate",
                "acknowledged_at": existing_response.responded_at,
                "sos_event_id": existing_response.sos_event_id,
            }
        except Exception as exc:
            db.rollback()
            safe_log_action(
                db,
                action="risk_alert.respond",
                status="failure",
                user_id=int(current_user_id),
                resource_type="alert",
                resource_id=int(notification_id),
                ip_address=ip_address,
                user_agent=user_agent,
                details={
                    "source": source,
                    "response_action": normalized_action,
                    "error_type": type(exc).__name__,
                },
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Không thể xử lý phản hồi cảnh báo rủi ro",
            )

    @staticmethod
    def get_sos_alerts_for_caregiver(
        db: Session,
        caregiver_user_id: int,
        status: str = "all"
    ) -> SOSAlertsResponse:
        """
        Get list of SOS alerts for a caregiver.
        
        Args:
            db: Database session
            caregiver_user_id: ID of the caregiver requesting alerts
            status: Filter by status ("all", "active", "resolved")
        """
        sos_events, total, active, resolved = EmergencyRepository.get_sos_alerts_by_caregiver(
            db, caregiver_user_id, status
        )
        risk_origin_sos_ids = EmergencyRepository.get_risk_response_sos_event_ids(
            db,
            [int(sos.id) for sos in sos_events],
        )

        # Bug fix G-3: per-patient location visibility. Caregivers viewing
        # their own SOS events (rare but possible when looking at the SOS
        # list while listed as a caregiver in another bidirectional pair)
        # are treated as the patient and always see their own coordinates.
        patient_ids_in_results = {
            int(sos.user_id)
            for sos in sos_events
            if sos.user_id is not None and int(sos.user_id) != int(caregiver_user_id)
        }
        location_visibility = (
            EmergencyRepository.get_caregiver_location_visibility(
                db,
                caregiver_user_id=int(caregiver_user_id),
                patient_user_ids=list(patient_ids_in_results),
            )
        )

        all_patient_ids = list({int(sos.user_id) for sos in sos_events if sos.user_id is not None})
        from app.models.user_model import User as _User
        patient_by_id = {
            int(u.id): u
            for u in db.query(_User).filter(_User.id.in_(all_patient_ids)).all()
        }

        sos_list_items = []
        for sos in sos_events:
            # Get patient info (from pre-fetched batch)
            patient = patient_by_id.get(int(sos.user_id)) if sos.user_id is not None else None
            if not patient:
                continue

            # Calculate elapsed time
            elapsed = datetime.now(timezone.utc) - sos.triggered_at
            elapsed_minutes = int(elapsed.total_seconds() / 60)

            trigger_type = EmergencyService._normalize_read_trigger_type(
                sos.trigger_type,
                is_risk_origin=int(sos.id) in risk_origin_sos_ids,
            )

            # Bug fix G-3: redact location for caregivers without
            # ``can_view_location``. Patients viewing their own SOS still see
            # the full coordinates.
            is_self_view = int(sos.user_id) == int(caregiver_user_id)
            can_view_location = is_self_view or location_visibility.get(
                int(sos.user_id), False
            )
            should_render_location = (
                can_view_location and (sos.latitude or sos.address)
            )

            sos_list_items.append(SOSEventListItem(
                sos_id=sos.id,
                patient=PatientInfo(
                    user_id=patient.id,
                    full_name=patient.full_name,
                    avatar_url=patient.avatar_url,
                    phone=patient.phone,
                    date_of_birth=patient.date_of_birth.isoformat() if patient.date_of_birth else None
                ),
                trigger_type=trigger_type,
                trigger_time=sos.triggered_at,
                status=sos.status,
                location=LocationInfo(
                    latitude=float(sos.latitude) if sos.latitude else None,
                    longitude=float(sos.longitude) if sos.longitude else None,
                    address=sos.address,
                    last_updated=sos.triggered_at
                ) if should_render_location else None,
                time_elapsed_minutes=elapsed_minutes
            ))

        return SOSAlertsResponse(
            sos_alerts=sos_list_items,
            total_count=total,
            active_count=active,
            resolved_count=resolved
        )

    @staticmethod
    def get_sos_detail(
        db: Session,
        sos_id: int,
        *,
        viewer_user_id: Optional[int] = None,
        viewer_is_admin: bool = False,
    ) -> Optional[SOSEventResponse]:
        """Get detailed SOS event information.

        Bug fix G-3: ``viewer_user_id`` and ``viewer_is_admin`` are optional so
        existing callers (tests, internal helpers) keep working without
        gating. The route layer in ``app/api/routes/emergency.py`` always
        passes the current user so caregivers without ``can_view_location``
        receive ``location=None`` even when the SOS event has coordinates.
        """
        sos = EmergencyRepository.get_sos_detail(db, sos_id)
        if not sos:
            return None

        # Get patient info
        patient = EmergencyRepository.get_user_by_id(db, sos.user_id)
        if not patient:
            return None

        risk_response = EmergencyRepository.get_risk_alert_response_by_sos_event_id(
            db,
            int(sos.id),
        )
        trigger_type = EmergencyService._normalize_read_trigger_type(
            sos.trigger_type,
            is_risk_origin=risk_response is not None,
        )

        # Get fall detection XAI if available — derived from FallEvent (no hardcoded mock).
        fall_xai = None
        if sos.fall_event_id:
            fall_event = EmergencyRepository.get_fall_event_by_id(db, sos.fall_event_id)
            if fall_event is not None:
                fall_xai = EmergencyService._build_fall_detection_xai(fall_event)

        # Get resolution info if resolved
        resolution_info = None
        if sos.status == 'resolved' and sos.resolved_at:
            resolver = EmergencyRepository.get_user_by_id(db, sos.resolved_by_user_id) if sos.resolved_by_user_id else None
            resolution_status, cleaned_notes = EmergencyService._parse_resolution_notes(
                sos.resolution_notes,
            )
            resolution_info = ResolutionInfo(
                resolved_at=sos.resolved_at,
                resolved_by_name=resolver.full_name if resolver else "Unknown",
                resolution_status=resolution_status,
                notes=cleaned_notes,
            )

        # Bug fix G-3: decide whether the viewer is allowed to see the
        # ``LocationInfo`` block. Patients viewing their own SOS, admins, and
        # any caller that didn't pass viewer context (legacy paths, tests)
        # still see the full payload. Caregivers must hold ``can_view_location``
        # on their accepted relationship row with this patient.
        can_view_location = True
        if (
            viewer_user_id is not None
            and not viewer_is_admin
            and int(viewer_user_id) != int(sos.user_id)
        ):
            permissions = EmergencyRepository.get_caregiver_view_permissions(
                db,
                patient_user_id=int(sos.user_id),
                caregiver_user_id=int(viewer_user_id),
            )
            # ``permissions is None`` means there is no accepted caregiver
            # relationship — the route's authorization check handles the 403,
            # but if we ever reach here without one we redact defensively.
            can_view_location = bool(
                permissions and permissions[1]
            )

        should_render_location = can_view_location and (
            sos.latitude or sos.address
        )

        return SOSEventResponse(
            sos_id=sos.id,
            patient=PatientInfo(
                user_id=patient.id,
                full_name=patient.full_name,
                avatar_url=patient.avatar_url,
                phone=patient.phone,
                date_of_birth=patient.date_of_birth.isoformat() if patient.date_of_birth else None
            ),
            trigger_type=trigger_type,
            trigger_time=sos.triggered_at,
            status=sos.status,
            location=LocationInfo(
                latitude=float(sos.latitude) if sos.latitude else None,
                longitude=float(sos.longitude) if sos.longitude else None,
                address=sos.address,
                accuracy=50.0 if sos.latitude else None,  # Mock accuracy only if coords exist
                last_updated=sos.triggered_at
            ) if should_render_location else None,
            fall_detection_xai=fall_xai,
            resolution=resolution_info
        )

    @staticmethod
    def resolve_sos_by_caregiver(
        db: Session,
        sos_id: int,
        caregiver_user_id: int,
        resolution_status: str,
        notes: Optional[str] = None
    ) -> bool:
        """Resolve SOS event (mark as safe/resolved)."""
        return EmergencyRepository.resolve_sos(
            db, sos_id, caregiver_user_id, resolution_status, notes
        )

    @staticmethod
    def _build_fall_detection_xai(fall_event: Any) -> Optional[FallDetectionXAI]:
        """Build a :class:`FallDetectionXAI` from a persisted ``FallEvent``.

        Replaces the previous hardcoded ``"15.2g/250ms"`` mock (P1 #4 fix). The
        output now reflects only what was actually captured:

        - ``confidence`` is the stored value (no fake ``0.95`` default).
        - ``timeline`` is sourced from ``fall_event.features['timeline']`` when
          the IoT/IMU pipeline persists one (e.g. when ``fall_service.predict``
          response is stored). Otherwise it degrades to a single ``T+0s``
          marker so the UI still shows when the event was detected.
        - ``trigger_reason`` prefers a stored model-api ``explanation.short_text``
          if present; otherwise falls back to a transparent Vietnamese
          description that names confidence + simulator variant + source.
        """
        if fall_event is None:
            return None

        confidence_raw = getattr(fall_event, "confidence", None)
        try:
            confidence = float(confidence_raw) if confidence_raw is not None else 0.0
        except (TypeError, ValueError):
            confidence = 0.0

        features = getattr(fall_event, "features", None)
        if not isinstance(features, dict):
            features = {}

        timeline = EmergencyService._extract_fall_timeline(features, confidence)
        trigger_reason = EmergencyService._extract_fall_trigger_reason(features, confidence)

        return FallDetectionXAI(
            confidence=confidence,
            timeline=timeline,
            trigger_reason=trigger_reason,
        )

    @staticmethod
    def _extract_fall_timeline(
        features: dict[str, Any],
        confidence: float,
    ) -> List[TimelineEvent]:
        """Return real timeline entries when persisted, else a single detection marker."""
        persisted = features.get("timeline")
        if isinstance(persisted, list):
            entries: list[TimelineEvent] = []
            for item in persisted:
                if not isinstance(item, dict):
                    continue
                offset = str(item.get("time_offset") or item.get("t") or "").strip()
                event_text = str(item.get("event") or item.get("description") or "").strip()
                if offset and event_text:
                    entries.append(TimelineEvent(time_offset=offset, event=event_text))
            if entries:
                return entries

        return [
            TimelineEvent(
                time_offset="T+0s",
                event=f"Phát hiện sự kiện té ngã (độ tin cậy {confidence:.0%})",
            )
        ]

    @staticmethod
    def _extract_fall_trigger_reason(
        features: dict[str, Any],
        confidence: float,
    ) -> str:
        explanation = features.get("explanation")
        if isinstance(explanation, dict):
            short_text = str(explanation.get("short_text") or "").strip()
            if short_text:
                return short_text

        parts: list[str] = []
        if confidence > 0:
            parts.append(f"Độ tin cậy phát hiện {confidence:.0%}")
        variant = str(features.get("variant") or features.get("fall_variant") or "").strip()
        if variant:
            parts.append(f"biến thể: {variant}")
        source = str(features.get("source") or "").strip()
        if source:
            parts.append(f"nguồn: {source}")
        if not parts:
            return "Đã phát hiện sự kiện té ngã từ thiết bị đeo."
        return ". ".join(parts) + "."
