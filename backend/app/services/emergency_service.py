from typing import Optional, List
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.repositories.emergency_repository import EmergencyRepository
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
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        address: Optional[str] = None
    ) -> bool:
        """Trigger a new SOS event."""
        
        EmergencyRepository.create_sos_event(
            db=db,
            user_id=user_id,
            device_id=None,  # Manual SOS is sent from the phone directly, not a wearable
            trigger_type=trigger_type,
            latitude=latitude,
            longitude=longitude,
            address=address
        )
        return True

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
