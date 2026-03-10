from typing import List, Optional, Tuple
from datetime import datetime, timezone

from sqlalchemy import and_, or_, func
from sqlalchemy.orm import Session, joinedload

from app.models.sos_event_model import SOSEvent, FallEvent
from app.models.user_model import User


class EmergencyRepository:
    """Repository for emergency/SOS event database operations."""

    @staticmethod
    def get_sos_alerts_by_caregiver(
        db: Session,
        caregiver_user_id: int,
        status_filter: str = "all",
        limit: int = 100,
        offset: int = 0
    ) -> Tuple[List[SOSEvent], int, int, int]:
        """
        Get SOS alerts for a caregiver (filtered by their assigned patients).
        
        Returns:
            Tuple of (sos_events, total_count, active_count, resolved_count)
        """
        # TODO: Implement caregiver-patient relationship check
        # For now, return all SOS events (admin view)
        
        query = db.query(SOSEvent)
        
        # Apply status filter
        if status_filter == "active":
            query = query.filter(SOSEvent.status == 'active')
        elif status_filter == "resolved":
            query = query.filter(SOSEvent.status == 'resolved')
        # "all" = no filter
        
        # Get counts
        total_count = query.count()
        active_count = db.query(func.count(SOSEvent.id)).filter(SOSEvent.status == 'active').scalar()
        resolved_count = db.query(func.count(SOSEvent.id)).filter(SOSEvent.status == 'resolved').scalar()
        
        # Get paginated results, ordered by most recent first
        sos_events = (
            query
            .order_by(SOSEvent.triggered_at.desc())
            .limit(limit)
            .offset(offset)
            .all()
        )
        
        return sos_events, total_count, active_count, resolved_count

    @staticmethod
    def get_sos_detail(db: Session, sos_id: int) -> Optional[SOSEvent]:
        """Get detailed SOS event by ID."""
        return db.query(SOSEvent).filter(SOSEvent.id == sos_id).first()

    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
        """Get user information."""
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def get_fall_event_by_id(db: Session, fall_event_id: int) -> Optional[FallEvent]:
        """Get fall event by ID for XAI data."""
        return db.query(FallEvent).filter(FallEvent.id == fall_event_id).first()

    @staticmethod
    def resolve_sos(
        db: Session,
        sos_id: int,
        resolved_by_user_id: int,
        resolution_status: str,
        notes: Optional[str] = None
    ) -> bool:
        """
        Mark SOS event as resolved by caregiver.
        
        Returns:
            True if successful, False if SOS not found
        """
        sos = db.query(SOSEvent).filter(SOSEvent.id == sos_id).first()
        
        if not sos:
            return False
        
        sos.status = 'resolved'
        sos.resolved_at = datetime.now(timezone.utc)
        sos.resolved_by_user_id = resolved_by_user_id
        sos.resolution_notes = f"[{resolution_status}] {notes or 'No notes'}"
        
        db.commit()
        db.refresh(sos)
        
        return True

    @staticmethod
    def create_sos_event(
        db: Session,
        user_id: int,
        device_id: int,
        trigger_type: str,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        address: Optional[str] = None,
        fall_event_id: Optional[int] = None
    ) -> SOSEvent:
        """Create a new SOS event."""
        sos = SOSEvent(
            user_id=user_id,
            device_id=device_id,
            trigger_type=trigger_type,
            triggered_at=datetime.now(timezone.utc),
            latitude=latitude,
            longitude=longitude,
            address=address,
            fall_event_id=fall_event_id,
            status='active'
        )
        
        db.add(sos)
        db.commit()
        db.refresh(sos)
        
        return sos
