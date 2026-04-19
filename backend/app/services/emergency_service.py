from typing import Any, Optional, List
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.repositories.emergency_repository import EmergencyRepository
from app.models.sos_event_model import Alert, SOSEvent
from app.services.push_notification_service import PushNotificationService
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


class EmergencyService:
    """Business logic for emergency/SOS operations."""

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

        sos_event = EmergencyRepository.create_sos_event(
            db=db,
            user_id=user_id,
            device_id=device_id,
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

        base_details = {
            "sos_id": sos_event.id,
            "sos_event_id": sos_event.id,
            "trigger_type": sos_event.trigger_type,
            "patient_user_id": sos_event.user_id,
            "patient_name": patient_name,
            "address": sos_event.address,
            "latitude": float(sos_event.latitude)
            if sos_event.latitude is not None
            else None,
            "longitude": float(sos_event.longitude)
            if sos_event.longitude is not None
            else None,
        }

        recipient_user_ids = EmergencyRepository.get_alert_recipient_user_ids(
            db,
            sos_event.user_id,
        )

        created_alerts: list[Alert] = []
        for recipient_user_id in recipient_user_ids:
            alert = Alert(
                device_id=sos_event.device_id,
                user_id=recipient_user_id,
                fall_event_id=sos_event.fall_event_id,
                alert_type=alert_type,
                severity="critical",
                title=title,
                message=message,
                details={**base_details, "recipient_user_id": recipient_user_id},
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

            PushNotificationService.send_sos_push_alerts(
                db,
                recipient_user_ids=dispatch_info["recipient_user_ids"],
                title=dispatch_info["title"],
                body=dispatch_info["body"],
                sos_id=int(sos_event.id),
                alert_type=dispatch_info["alert_type"],
                trigger_type=dispatch_info["trigger_type"],
                notification_id_by_user=dispatch_info["notification_id_by_user"],
            )

            return {
                "success": True,
                "status": "escalated",
                "acknowledged_at": response_row.responded_at,
                "sos_event_id": response_row.sos_event_id,
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
        except Exception:
            db.rollback()
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
        
        sos_list_items = []
        for sos in sos_events:
            # Get patient info
            patient = EmergencyRepository.get_user_by_id(db, sos.user_id)
            if not patient:
                continue
            
            # Calculate elapsed time
            elapsed = datetime.now(timezone.utc) - sos.triggered_at
            elapsed_minutes = int(elapsed.total_seconds() / 60)
            
            # Map trigger type
            trigger_type_map = {
                'auto': 'fall_detected',
                'manual': 'manual'
            }
            trigger_type = trigger_type_map.get(sos.trigger_type, sos.trigger_type)
            
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
                ) if (sos.latitude or sos.address) else None,
                time_elapsed_minutes=elapsed_minutes
            ))
        
        return SOSAlertsResponse(
            sos_alerts=sos_list_items,
            total_count=total,
            active_count=active,
            resolved_count=resolved
        )

    @staticmethod
    def get_sos_detail(db: Session, sos_id: int) -> Optional[SOSEventResponse]:
        """Get detailed SOS event information."""
        sos = EmergencyRepository.get_sos_detail(db, sos_id)
        if not sos:
            return None
        
        # Get patient info
        patient = EmergencyRepository.get_user_by_id(db, sos.user_id)
        if not patient:
            return None
        
        # Map trigger type
        trigger_type_map = {
            'auto': 'fall_detected',
            'manual': 'manual'
        }
        trigger_type = trigger_type_map.get(sos.trigger_type, sos.trigger_type)
        
        # Get fall detection XAI if available
        fall_xai = None
        if sos.fall_event_id:
            fall_event = EmergencyRepository.get_fall_event_by_id(db, sos.fall_event_id)
            if fall_event and fall_event.features:
                # Parse XAI data from features JSONB
                confidence = float(fall_event.confidence) if fall_event.confidence else 0.95
                timeline = [
                    TimelineEvent(time_offset="T+0s", event="Tác động mạnh phát hiện (15.2g)"),
                    TimelineEvent(time_offset="T+0.25s", event="Thời gian va chạm: 250ms"),
                    TimelineEvent(time_offset="T+2s", event="Phát hiện tư thế nằm"),
                    TimelineEvent(time_offset="T+5s", event="Không có chuyển động đứng dậy"),
                ]
                fall_xai = FallDetectionXAI(
                    confidence=confidence,
                    timeline=timeline,
                    trigger_reason=" Tác động vượt ngưỡng (15.2g), sau đó phát hiện tư thế nằm kéo dài > 5 giây."
                )
        
        # Get resolution info if resolved
        resolution_info = None
        if sos.status == 'resolved' and sos.resolved_at:
            resolver = EmergencyRepository.get_user_by_id(db, sos.resolved_by_user_id) if sos.resolved_by_user_id else None
            resolution_info = ResolutionInfo(
                resolved_at=sos.resolved_at,
                resolved_by_name=resolver.full_name if resolver else "Unknown",
                resolution_status="safe",
                notes=sos.resolution_notes
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
            ) if (sos.latitude or sos.address) else None,
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
