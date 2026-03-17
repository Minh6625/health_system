from typing import List, Optional, Tuple
from datetime import datetime, timezone

from sqlalchemy import and_, or_, func, exists
from sqlalchemy.orm import Session, joinedload

from app.models.sos_event_model import SOSEvent, FallEvent
from app.models.user_model import User
from app.models.relationship_model import UserRelationship


class EmergencyRepository:
    """Repository for emergency/SOS event database operations."""

    @staticmethod
    def check_user_has_access(db: Session, viewer_id: int, target_user_id: int) -> bool:
        """Check if viewer can see target user's SOS (same user or linked)."""
        if viewer_id == target_user_id:
            return True
            
        rel = db.query(UserRelationship).filter(
            or_(
                and_(UserRelationship.patient_id == target_user_id, UserRelationship.caregiver_id == viewer_id),
                and_(UserRelationship.patient_id == viewer_id, UserRelationship.caregiver_id == target_user_id)
            ),
            UserRelationship.status == "accepted"
        ).first()
        return rel is not None

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
        Only show events triggered AFTER the relationship was established.
        Does not show caregiver's own events.

        Returns:
            Tuple of (sos_events, total_count, active_count, resolved_count)
        """
        caregiver_rel_exists = exists().where(
            and_(
                UserRelationship.caregiver_id == caregiver_user_id,
                UserRelationship.patient_id == SOSEvent.user_id,
                UserRelationship.status == "accepted",
                SOSEvent.triggered_at >= UserRelationship.created_at
            )
        )
        patient_rel_exists = exists().where(
            and_(
                UserRelationship.patient_id == caregiver_user_id,
                UserRelationship.caregiver_id == SOSEvent.user_id,
                UserRelationship.status == "accepted",
                SOSEvent.triggered_at >= UserRelationship.created_at
            )
        )

        base_filter = or_(caregiver_rel_exists, patient_rel_exists)

        query = db.query(SOSEvent).filter(base_filter)

        # Apply status filter
        if status_filter == "active":
            query = query.filter(SOSEvent.status == 'active')
        elif status_filter == "resolved":
            query = query.filter(SOSEvent.status == 'resolved')
        # "all" = no filter

        # Get counts
        total_count = query.count()
        active_count = db.query(func.count(SOSEvent.id)).filter(
            base_filter,
            SOSEvent.status == 'active'
        ).scalar()
        resolved_count = db.query(func.count(SOSEvent.id)).filter(
            base_filter,
            SOSEvent.status == 'resolved'
        ).scalar()
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
        trigger_type: str,
        device_id: Optional[int] = None,
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
