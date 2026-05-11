from typing import List, Optional, Tuple
from datetime import datetime, timezone

from sqlalchemy import and_, or_, func, exists, case
from sqlalchemy.orm import Session, joinedload

from app.models.device_model import Device
from app.models.risk_alert_response_model import RiskAlertResponse
from app.models.sos_event_model import Alert, SOSEvent, FallEvent
from app.models.user_model import User
from app.models.relationship_model import UserRelationship


class EmergencyRepository:
    """Repository for emergency/SOS event database operations."""

    @staticmethod
    def get_alert_by_id(db: Session, alert_id: int) -> Optional[Alert]:
        return db.query(Alert).filter(Alert.id == alert_id).first()

    @staticmethod
    def get_risk_alert_response(
        db: Session,
        notification_id: int,
    ) -> Optional[RiskAlertResponse]:
        return (
            db.query(RiskAlertResponse)
            .filter(RiskAlertResponse.notification_id == notification_id)
            .first()
        )

    @staticmethod
    def get_risk_alert_response_by_sos_event_id(
        db: Session,
        sos_event_id: int,
    ) -> Optional[RiskAlertResponse]:
        return (
            db.query(RiskAlertResponse)
            .filter(RiskAlertResponse.sos_event_id == sos_event_id)
            .first()
        )

    @staticmethod
    def get_risk_response_sos_event_ids(
        db: Session,
        sos_event_ids: list[int],
    ) -> set[int]:
        if not sos_event_ids:
            return set()

        rows = (
            db.query(RiskAlertResponse.sos_event_id)
            .filter(RiskAlertResponse.sos_event_id.in_(sos_event_ids))
            .all()
        )
        return {
            int(sos_event_id)
            for (sos_event_id,) in rows
            if sos_event_id is not None
        }

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
        # Bug fix G-4: gate the SOS list by ``can_receive_alerts`` so a
        # caregiver who has been revoked from receiving alerts also stops
        # seeing the underlying SOS event in their list. Previously this
        # only filtered the push fan-out (see
        # ``get_alert_recipient_user_ids``), which left an asymmetric leak
        # where the SOS-list tab still showed events the caregiver was no
        # longer entitled to.
        caregiver_rel_exists = exists().where(
            and_(
                UserRelationship.caregiver_id == caregiver_user_id,
                UserRelationship.patient_id == SOSEvent.user_id,
                UserRelationship.status == "accepted",
                UserRelationship.can_receive_alerts.is_(True),
                SOSEvent.triggered_at >= UserRelationship.created_at
            )
        )
        patient_rel_exists = exists().where(
            and_(
                UserRelationship.patient_id == caregiver_user_id,
                UserRelationship.caregiver_id == SOSEvent.user_id,
                UserRelationship.status == "accepted",
                UserRelationship.can_receive_alerts.is_(True),
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

        # Get all counts in a single aggregation query to reduce round-trips
        counts_row = db.query(
            func.count(SOSEvent.id).label("total"),
            func.sum(case((SOSEvent.status == "active", 1), else_=0)).label("active"),
            func.sum(case((SOSEvent.status == "resolved", 1), else_=0)).label("resolved"),
        ).filter(base_filter).first()
        total_count = int(counts_row.total or 0)
        active_count = int(counts_row.active or 0)
        resolved_count = int(counts_row.resolved or 0)
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
        fall_event_id: Optional[int] = None,
        *,
        commit: bool = True,
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
        db.flush()
        if commit:
            db.commit()
            db.refresh(sos)
        
        return sos

    @staticmethod
    def create_risk_alert_response(
        db: Session,
        *,
        notification_id: int,
        response_action: str,
        source: str,
        risk_score_id: Optional[int] = None,
        device_id: Optional[int] = None,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
        address: Optional[str] = None,
        sos_event_id: Optional[int] = None,
    ) -> RiskAlertResponse:
        response = RiskAlertResponse(
            notification_id=notification_id,
            response_action=response_action,
            risk_score_id=risk_score_id,
            source=source,
            device_id=device_id,
            latitude=latitude,
            longitude=longitude,
            address=address,
            sos_event_id=sos_event_id,
        )
        db.add(response)
        db.flush()
        return response

    @staticmethod
    def get_active_device_id_for_user(
        db: Session,
        user_id: int,
    ) -> int | None:
        row = (
            db.query(Device.id)
            .filter(
                Device.user_id == user_id,
                Device.is_active.is_(True),
                Device.deleted_at.is_(None),
            )
            .order_by(Device.registered_at.desc(), Device.id.desc())
            .first()
        )
        if row is None:
            return None
        return int(row[0])

    @staticmethod
    def get_alert_recipient_user_ids(
        db: Session,
        patient_user_id: int,
    ) -> list[int]:
        """Return caregiver user IDs that should receive SOS/fall alerts for a patient."""
        caregiver_rows = (
            db.query(UserRelationship.caregiver_id)
            .filter(
                UserRelationship.patient_id == patient_user_id,
                UserRelationship.status == "accepted",
                UserRelationship.can_receive_alerts.is_(True),
                UserRelationship.deleted_at.is_(None),
            )
            .all()
        )

        recipient_ids: set[int] = set()
        for (caregiver_id,) in caregiver_rows:
            if caregiver_id is not None:
                recipient_ids.add(int(caregiver_id))

        return list(recipient_ids)

    @staticmethod
    def get_sos_alert_recipients_with_permissions(
        db: Session,
        patient_user_id: int,
    ) -> List[Tuple[int, bool]]:
        """Return ``[(caregiver_user_id, can_view_location), ...]`` for caregivers
        that should receive SOS/fall alerts for ``patient_user_id``.

        Bug fix G-3: callers previously used
        :meth:`get_alert_recipient_user_ids` and then leaked
        ``latitude/longitude/address`` to every recipient regardless of
        ``can_view_location``. This helper surfaces both flags in one query so
        :meth:`EmergencyService._create_alerts_for_sos_event` can redact the
        location fields per recipient instead of trusting the patient's row.
        """
        rows = (
            db.query(
                UserRelationship.caregiver_id,
                UserRelationship.can_view_location,
            )
            .filter(
                UserRelationship.patient_id == patient_user_id,
                UserRelationship.status == "accepted",
                UserRelationship.can_receive_alerts.is_(True),
                UserRelationship.deleted_at.is_(None),
            )
            .all()
        )

        # Collapse duplicate caregiver rows (legacy data may have multiple
        # accepted rows per pair). Grant the most permissive view we can find
        # so a caregiver with at least one row that allows location still sees
        # it; a caregiver whose every row revoked location stays redacted.
        seen: dict[int, bool] = {}
        for caregiver_id, can_view_location in rows:
            if caregiver_id is None:
                continue
            cid = int(caregiver_id)
            seen[cid] = seen.get(cid, False) or bool(can_view_location)

        return list(seen.items())

    @staticmethod
    def get_caregiver_view_permissions(
        db: Session,
        *,
        patient_user_id: int,
        caregiver_user_id: int,
    ) -> Optional[Tuple[bool, bool]]:
        """Return ``(can_receive_alerts, can_view_location)`` for the accepted
        relationship row where ``caregiver_user_id`` is the caregiver of
        ``patient_user_id``, or ``None`` if no such row exists.

        Bug fix G-3: used by the SOS read endpoints
        (:meth:`EmergencyService.get_sos_alerts_for_caregiver`,
        :meth:`EmergencyService.get_sos_detail`) to gate the
        ``LocationInfo`` field per viewer. Patients viewing their own SOS and
        admins bypass this lookup at the service layer.
        """
        rel = (
            db.query(UserRelationship)
            .filter(
                UserRelationship.patient_id == patient_user_id,
                UserRelationship.caregiver_id == caregiver_user_id,
                UserRelationship.status == "accepted",
                UserRelationship.deleted_at.is_(None),
            )
            .first()
        )
        if rel is None:
            return None
        return bool(rel.can_receive_alerts), bool(rel.can_view_location)

    @staticmethod
    def get_caregiver_location_visibility(
        db: Session,
        *,
        caregiver_user_id: int,
        patient_user_ids: List[int],
    ) -> dict[int, bool]:
        """Return ``{patient_user_id: can_view_location}`` for all accepted
        relationships where ``caregiver_user_id`` is the caregiver.

        Bug fix G-3: batches the per-patient location-permission lookup that
        :meth:`EmergencyService.get_sos_alerts_for_caregiver` needs when
        rendering a SOS list spanning multiple patients. Patients absent from
        the result map have no accepted relationship with this caregiver and
        the caller should default to ``False`` (redact location).
        """
        if not patient_user_ids:
            return {}

        rows = (
            db.query(
                UserRelationship.patient_id,
                UserRelationship.can_view_location,
            )
            .filter(
                UserRelationship.caregiver_id == caregiver_user_id,
                UserRelationship.patient_id.in_(patient_user_ids),
                UserRelationship.status == "accepted",
                UserRelationship.deleted_at.is_(None),
            )
            .all()
        )

        visibility: dict[int, bool] = {}
        for patient_id, can_view_location in rows:
            if patient_id is None:
                continue
            pid = int(patient_id)
            # Match the ``OR`` semantics of
            # :meth:`get_sos_alert_recipients_with_permissions`: if the
            # caregiver has *any* accepted row with the flag granted, they
            # can see location.
            visibility[pid] = visibility.get(pid, False) or bool(
                can_view_location
            )
        return visibility
