from typing import List, Dict, Any, Optional
from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.relationship_model import UserRelationship
from app.models.user_model import User
from app.repositories.relationship_repository import RelationshipRepository
from app.repositories.user_repository import UserRepository
from app.schemas.relationship import AccessProfileResponse, RelationshipRequestCreate, RelationshipResponse, UserSearchResponse


class RelationshipService:

    @staticmethod
    def search_users(db: Session, current_user: User, query: str) -> List[UserSearchResponse]:
        if not query or len(query.strip()) < 2:
            return []
        
        q = query.strip().lower()
        users = db.query(User).filter(
            (User.id != current_user.id) &
            (User.deleted_at == None) &  # noqa: E711 — SQLAlchemy requires == None
            (User.is_active == True) &
            (User.is_verified == True) &
            (
                (User.email.ilike(f"%{q}%")) | 
                (User.phone.ilike(f"%{q}%")) | 
                (User.full_name.ilike(f"%{q}%"))
            )
        ).limit(20).all()

        user_ids = [u.id for u in users]
        rels = []
        if user_ids:
            rels = db.query(UserRelationship).filter(
                ((UserRelationship.patient_id == current_user.id) & (UserRelationship.caregiver_id.in_(user_ids))) |
                ((UserRelationship.caregiver_id == current_user.id) & (UserRelationship.patient_id.in_(user_ids)))
            ).all()

        rels_by_partner: Dict[int, List[UserRelationship]] = {}
        for rel in rels:
            partner_id = rel.caregiver_id if rel.patient_id == current_user.id else rel.patient_id
            rels_by_partner.setdefault(partner_id, []).append(rel)

        responses: List[UserSearchResponse] = []
        for u in users:
            partner_rels = rels_by_partner.get(u.id, [])

            connection_status = "none"
            relationship_id = None
            is_incoming = False

            accepted_rel = next((r for r in partner_rels if r.status == "accepted"), None)
            incoming_pending_rel = next(
                (
                    r for r in partner_rels
                    if r.status == "pending" and r.patient_id == current_user.id
                ),
                None,
            )
            outgoing_pending_rel = next(
                (
                    r for r in partner_rels
                    if r.status == "pending" and r.caregiver_id == current_user.id
                ),
                None,
            )

            if accepted_rel:
                connection_status = "accepted"
                relationship_id = accepted_rel.id
            elif incoming_pending_rel:
                connection_status = "pending"
                relationship_id = incoming_pending_rel.id
                is_incoming = True
            elif outgoing_pending_rel:
                connection_status = "pending"
                relationship_id = outgoing_pending_rel.id

            responses.append(
                UserSearchResponse(
                    id=u.id,
                    full_name=u.full_name,
                    email=u.email,
                    phone=u.phone,
                    avatar_url=u.avatar_url,
                    connection_status=connection_status,
                    relationship_id=relationship_id,
                    is_incoming=is_incoming,
                )
            )

        return responses

    @staticmethod
    def _family_sleep_quality_label(quality_label: str | None) -> str:
        normalized = str(quality_label or "").strip().lower()
        if normalized in {"good", "tot", "tốt"}:
            return "Tốt"
        if normalized in {"poor", "kem", "kém"}:
            return "Kém"
        return "Trung bình"

    @staticmethod
    def _family_health_level_label(health_level: str | None) -> str:
        normalized = str(health_level or "").strip().lower()
        if normalized in {"stable", "good", "high"}:
            return "Cao"
        if normalized in {"critical", "poor", "low"}:
            return "Thấp"
        return "Trung bình"

    @staticmethod
    def _family_vitals_unavailable_message(
        db: Session,
        user_id: int,
        has_device: bool | None = None,
    ) -> str:
        if has_device is None:
            has_device = db.execute(
                text(
                    """
                    SELECT 1
                    FROM devices
                    WHERE user_id = :user_id
                    LIMIT 1
                    """
                ),
                {"user_id": user_id},
            ).first() is not None
        if has_device:
            return "Thiết bị đã kết nối nhưng chưa có dữ liệu đo."
        return "Người dùng chưa kết nối thiết bị với tài khoản."

    @staticmethod
    def get_access_profiles(db: Session, current_user: User) -> List[AccessProfileResponse]:
        profiles = []
        
        # 1. Add self (the root profile)
        profiles.append(AccessProfileResponse(
            id=current_user.id,
            full_name=current_user.full_name,
            avatar_url=current_user.avatar_url,
            relationship_type="self",
            can_view_vitals=True,
            can_receive_alerts=True,
            can_view_location=True
        ))
        
        # 2. Add linked profiles (where current_user is the caregiver, and status is accepted)
        linked_relationships = RelationshipRepository.get_viewable_profiles(db, current_user.id)
        patient_ids = [r.patient_id for r in linked_relationships]
        patients_map = {
            u.id: u
            for u in db.query(User).filter(User.id.in_(patient_ids)).all()
        } if patient_ids else {}
        for rel in linked_relationships:
            patient = patients_map.get(rel.patient_id)
            if patient:
                profiles.append(AccessProfileResponse(
                    id=patient.id,
                    full_name=patient.full_name,
                    avatar_url=patient.avatar_url,
                    relationship_type=rel.relationship_type,
                    can_view_vitals=rel.can_view_vitals,
                    can_receive_alerts=rel.can_receive_alerts,
                    can_view_location=rel.can_view_location
                ))
                
        return profiles

    @staticmethod
    def get_relationship_snapshot(
        db: Session, relationship_id: int
    ) -> Optional[dict]:
        """Return a JSON-friendly snapshot of a relationship's permission
        bits, used by audit log writers BEFORE update/delete so the audit
        row carries ``permissions_before`` (the post-mutation state is
        derived from the request payload or another fresh fetch).

        Returns ``None`` when the relationship does not exist; callers
        translate that into the standard 404 path and skip auditing.
        """
        rel = RelationshipRepository.get_by_id(db, relationship_id)
        if rel is None:
            return None
        return {
            "id": int(rel.id),
            "patient_id": int(rel.patient_id) if rel.patient_id is not None else None,
            "caregiver_id": int(rel.caregiver_id)
            if rel.caregiver_id is not None
            else None,
            "status": rel.status,
            "relationship_type": getattr(rel, "relationship_type", None),
            "can_view_vitals": bool(getattr(rel, "can_view_vitals", False)),
            "can_view_location": bool(getattr(rel, "can_view_location", False)),
            "can_view_medical_info": bool(
                getattr(rel, "can_view_medical_info", False)
            ),
            "can_receive_alerts": bool(getattr(rel, "can_receive_alerts", False)),
        }

    @staticmethod
    def request_relationship(db: Session, current_user: User, payload: RelationshipRequestCreate) -> UserRelationship:
        if not payload.email and not payload.phone and not payload.target_user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Must provide email, phone number, or target_user_id to find user"
            )
            
        target_user = None
        if payload.target_user_id:
            target_user = UserRepository.get_by_id(db, payload.target_user_id)
        elif payload.email:
            target_user = UserRepository.get_by_email(db, payload.email)
        elif payload.phone:
            # Assumes we have a get_by_phone method, fallback to query
            target_user = db.query(User).filter(User.phone == payload.phone).first()
            
        if not target_user or target_user.deleted_at is not None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy người dùng với thông tin này"
            )

        if not target_user.is_active or not target_user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tài khoản người dùng này chưa được kích hoạt hoặc xác thực"
            )

        if target_user.id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Không thể gửi yêu cầu cho chính mình"
            )
            
        # Check if relationship already exists
        existing_rel = db.query(UserRelationship).filter(
            UserRelationship.patient_id == target_user.id,
            UserRelationship.caregiver_id == current_user.id
        ).first()
        
        if existing_rel:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Mối quan hệ đã tồn tại hoặc đang chờ xác nhận"
            )
            
        tags = payload.tags if isinstance(payload.tags, list) else []
        inferred_primary_label = payload.primary_relationship_label
        if not inferred_primary_label and tags:
            first_tag = tags[0]
            if isinstance(first_tag, dict):
                inferred_primary_label = first_tag.get("name") or first_tag.get("id")
            else:
                inferred_primary_label = str(first_tag)

        # Create as pending
        new_rel = UserRelationship(
            patient_id=target_user.id,        # The one being requested (they must accept)
            caregiver_id=current_user.id,     # The one sending the request (wants to view)
            relationship_type=payload.relationship_type,
            status="pending",
            primary_relationship_label=inferred_primary_label,
            tags=tags,
            can_view_vitals=False,
            can_receive_alerts=False,
            can_view_location=False
        )
        
        return RelationshipRepository.create(db, new_rel)

    @staticmethod
    def accept_relationship(db: Session, current_user: User, relationship_id: int) -> UserRelationship:
        rel = RelationshipRepository.get_by_id(db, relationship_id)
        if not rel:
            raise HTTPException(status_code=404, detail="Không tìm thấy yêu cầu")
            
        # Only the patient can accept the caregiver's request
        if rel.patient_id != current_user.id:
            raise HTTPException(status_code=403, detail="Không có quyền xác nhận yêu cầu này")
            
        rel.status = "accepted"
        rel.can_view_vitals = True
        rel.can_receive_alerts = True
        RelationshipRepository.update(db, rel)
        
        # Check if inverse relationship already exists (exclude soft-deleted rows
        # so a deleted inverse doesn't block creating a fresh one).
        existing_inverse_rel = db.query(UserRelationship).filter(
            UserRelationship.patient_id == rel.caregiver_id,
            UserRelationship.caregiver_id == rel.patient_id,
            UserRelationship.deleted_at.is_(None),
        ).first()

        # If it doesn't exist, create it (Patient views Caregiver)
        if not existing_inverse_rel:
            inverse_rel = UserRelationship(
                patient_id=rel.caregiver_id,
                caregiver_id=rel.patient_id,
                relationship_type=rel.relationship_type,
                primary_relationship_label=rel.primary_relationship_label,
                tags=rel.tags if isinstance(rel.tags, list) else [],
                status="accepted",
                can_view_vitals=True,
                can_receive_alerts=True,
                can_view_location=False,
                # P-4: medical info is opt-in (privacy-preserving default).
                # Patient must explicitly toggle this on per partner via
                # LinkedContactDetailScreen; we never auto-grant it on accept.
                can_view_medical_info=False,
            )
            RelationshipRepository.create(db, inverse_rel)
            
        return rel

    @staticmethod
    def delete_relationship(db: Session, current_user: User, relationship_id: int) -> None:
        rel = RelationshipRepository.get_by_id(db, relationship_id)
        if not rel:
            raise HTTPException(status_code=404, detail="Không tìm thấy liên kết")
            
        if rel.patient_id != current_user.id and rel.caregiver_id != current_user.id:
            raise HTTPException(status_code=403, detail="Không có quyền xóa liên kết này")

        inverse_rel = db.query(UserRelationship).filter(
            UserRelationship.patient_id == rel.caregiver_id,
            UserRelationship.caregiver_id == rel.patient_id
        ).first()

        RelationshipRepository.delete(db, rel)
        if inverse_rel:
            RelationshipRepository.delete(db, inverse_rel)

    # Permission columns that must always live on the patient-side row
    # (the row where patient_id == current_user.id), because they represent
    # "what I (the data-owner / patient) grant to my caregiver".
    _PERMISSION_KEYS: frozenset = frozenset({
        'can_view_vitals',
        'can_receive_alerts',
        'can_view_location',
        'can_view_medical_info',
    })

    @staticmethod
    def update_relationship(db: Session, current_user: User, relationship_id: int, payload: Any) -> UserRelationship:
        rel = RelationshipRepository.get_by_id(db, relationship_id)
        if not rel:
            raise HTTPException(status_code=404, detail="Không tìm thấy liên kết")

        if rel.patient_id != current_user.id and rel.caregiver_id != current_user.id:
            raise HTTPException(status_code=403, detail="Không có quyền cập nhật liên kết này")

        update_data = payload.dict(exclude_unset=True)

        # Bug fix G-5: ``primary_relationship_label`` represents what *the
        # current user* calls their partner (e.g. A labelling B as "Bố"). It
        # must therefore live on the row where the current user is the
        # caregiver (``caregiver_id == current_user.id``), regardless of
        # which side of the pair ``relationship_id`` happens to point at.
        label_value = update_data.pop("primary_relationship_label", None)
        if label_value is not None:
            partner_id = (
                rel.caregiver_id
                if rel.patient_id == current_user.id
                else rel.patient_id
            )
            caregiver_side_rel = (
                db.query(UserRelationship)
                .filter(
                    UserRelationship.caregiver_id == current_user.id,
                    UserRelationship.patient_id == partner_id,
                )
                .first()
            )
            target_for_label = caregiver_side_rel or rel
            target_for_label.primary_relationship_label = label_value
            if target_for_label is not rel:
                db.flush()

        # --- Permission routing fix ---
        # Permissions MUST land on the patient-side row (patient_id ==
        # current_user.id), because ``get_linked_contact_detail`` reads them
        # from exactly that row.  When the admin panel creates a relationship
        # it only inserts ONE row (the caregiver-side: patient=B, caregiver=A),
        # so the inverse row (patient=A, caregiver=B) may not yet exist.
        # If the given ``relationship_id`` is the caregiver-side row we must
        # find (or create) the patient-side row before writing permissions.
        permission_data = {k: v for k, v in update_data.items()
                          if k in RelationshipService._PERMISSION_KEYS}
        other_data = {k: v for k, v in update_data.items()
                      if k not in RelationshipService._PERMISSION_KEYS}

        if permission_data:
            if rel.patient_id == current_user.id:
                # rel is already the patient-side row — update in-place.
                permission_rel = rel
            else:
                # rel is the caregiver-side row; current user is the caregiver.
                # The partner (the patient of rel) needs to be the caregiver of
                # the patient-side row.
                partner_id = rel.patient_id
                permission_rel = (
                    db.query(UserRelationship)
                    .filter(
                        UserRelationship.patient_id == current_user.id,
                        UserRelationship.caregiver_id == partner_id,
                        UserRelationship.deleted_at.is_(None),
                    )
                    .first()
                )
                if permission_rel is None:
                    # Inverse row missing (admin-created relationship).
                    # Create it so permissions have a stable home.
                    permission_rel = UserRelationship(
                        patient_id=current_user.id,
                        caregiver_id=partner_id,
                        relationship_type=rel.relationship_type,
                        status='accepted',
                        can_view_vitals=False,
                        can_receive_alerts=False,
                        can_view_location=False,
                        can_view_medical_info=False,
                    )
                    db.add(permission_rel)
                    db.flush()  # populate permission_rel.id without committing yet

            for key, value in permission_data.items():
                setattr(permission_rel, key, value)

            if permission_rel is not rel:
                # Flush permission changes to DB before committing the whole tx.
                db.flush()
                # Return the patient-side row so format_relationships picks the
                # right ID when matching r["id"] == rel.id.
                rel = permission_rel

        # Non-permission fields (tags, relationship_type) stay on the original row.
        for key, value in other_data.items():
            setattr(rel, key, value)

        return RelationshipRepository.update(db, rel)

    @staticmethod
    def format_relationships(db: Session, user_id: int) -> List[Dict[str, Any]]:
        # Filter soft-deleted rows so format_relationships never returns a
        # deleted row as primary_rel (which would cause permission writes to
        # land on the wrong row and reads to always return []).
        rels = db.query(UserRelationship).filter(
            (UserRelationship.patient_id == user_id) |
            (UserRelationship.caregiver_id == user_id),
            UserRelationship.deleted_at.is_(None),
        ).all()
        
        # Group by partner_id
        grouped = {}
        for r in rels:
            partner_id = r.caregiver_id if r.patient_id == user_id else r.patient_id
            if partner_id not in grouped:
                grouped[partner_id] = []
            grouped[partner_id].append(r)
            
        all_user_ids = set()
        for partner_rels in grouped.values():
            for r in partner_rels:
                all_user_ids.add(r.patient_id)
                all_user_ids.add(r.caregiver_id)
        users_map = {
            u.id: u
            for u in db.query(User).filter(User.id.in_(list(all_user_ids))).all()
        } if all_user_ids else {}

        result = []
        for partner_id, partner_rels in grouped.items():
            primary_rel = None
            if len(partner_rels) > 1:
                # 2 rows means accepted
                for r in partner_rels:
                    if r.patient_id == user_id:
                        primary_rel = r
                        break
                if not primary_rel:
                    primary_rel = partner_rels[0]
            else:
                primary_rel = partner_rels[0]

            patient = users_map.get(primary_rel.patient_id)
            caregiver = users_map.get(primary_rel.caregiver_id)
            if not patient or not caregiver:
                continue
                
            inverse_rel = next((r for r in partner_rels if r.caregiver_id == user_id), None)

            # Bug fix G-5: ``primary_relationship_label`` is "what
            # ``user_id`` calls the partner". It therefore lives on the row
            # where ``user_id`` is the caregiver (``inverse_rel`` here).
            # ``primary_rel`` is the patient-side row used for permission
            # bookkeeping ("của tôi"); reading the label off it caused the
            # current user to see the *partner's* chosen label instead of
            # their own. Fall back to ``primary_rel.primary_relationship_label``
            # when no caregiver-side row exists yet (e.g. legacy data or
            # outgoing requests where only one row is present).
            label_source = inverse_rel or primary_rel
            display_label = label_source.primary_relationship_label

            res_dict = {
                "id": primary_rel.id,
                "patient_id": primary_rel.patient_id,
                "patient_name": patient.full_name,
                "patient_email": patient.email,
                "caregiver_id": primary_rel.caregiver_id,
                "caregiver_name": caregiver.full_name,
                "caregiver_email": caregiver.email,
                "relationship_type": primary_rel.relationship_type,
                "status": primary_rel.status,
                "primary_relationship_label": display_label,
                "tags": primary_rel.tags if primary_rel.tags else [],
                "can_view_vitals": primary_rel.can_view_vitals,
                "can_receive_alerts": primary_rel.can_receive_alerts,
                "can_view_location": primary_rel.can_view_location,
                # P-4: read off ``primary_rel`` (= row where current user is
                # the patient) because this trio represents "what I am
                # sharing with the partner". ``getattr`` keeps backward
                # compatibility with rows produced before the migration
                # landed (column may still be missing in legacy DB snapshots
                # used in unit tests).
                "can_view_medical_info": getattr(
                    primary_rel, "can_view_medical_info", False
                ),
                "created_at": primary_rel.created_at
            }
            
            if inverse_rel:
                res_dict["has_view_vitals_permission"] = inverse_rel.can_view_vitals
                res_dict["has_receive_alerts_permission"] = inverse_rel.can_receive_alerts
                res_dict["has_view_location_permission"] = inverse_rel.can_view_location
                res_dict["has_view_medical_info_permission"] = getattr(
                    inverse_rel, "can_view_medical_info", False
                )
            else:
                res_dict["has_view_vitals_permission"] = False
                res_dict["has_receive_alerts_permission"] = False
                res_dict["has_view_location_permission"] = False
                res_dict["has_view_medical_info_permission"] = False
                
            result.append(res_dict)
            
        return result
    @staticmethod
    def get_dashboard_snapshots(db: Session, current_user: User) -> List[Any]:
        from datetime import datetime, UTC
        from app.repositories.emergency_repository import EmergencyRepository
        from app.schemas.relationship import FamilyProfileSnapshot
        from app.services.monitoring_service import MonitoringService

        # Get all accepted relationships where current_user is caregiver or patient
        relationships = RelationshipRepository.get_user_relationships(db, current_user.id)

        # Group by contact_id to handle bidirectional relationships
        contact_rels = {}
        for rel in relationships:
            if rel.status == "accepted":
                contact_id = rel.patient_id if rel.caregiver_id == current_user.id else rel.caregiver_id
                if contact_id not in contact_rels:
                    contact_rels[contact_id] = []
                contact_rels[contact_id].append(rel)

        try:
            active_sos_events, _, _, _ = EmergencyRepository.get_sos_alerts_by_caregiver(
                db,
                current_user.id,
                status_filter="active",
            )
        except Exception:
            active_sos_events = []

        latest_active_sos_by_user: Dict[int, Any] = {}
        for event in active_sos_events:
            latest_active_sos_by_user.setdefault(event.user_id, event)

        contact_ids = list(contact_rels.keys())
        contacts_map = {
            u.id: u
            for u in db.query(User).filter(User.id.in_(contact_ids)).all()
        } if contact_ids else {}

        from sqlalchemy import text as _text
        contacts_with_devices: set[int] = set()
        if contact_ids:
            rows = db.execute(
                _text(
                    "SELECT DISTINCT user_id FROM devices "
                    "WHERE user_id = ANY(:ids) AND deleted_at IS NULL"
                ),
                {"ids": contact_ids},
            ).all()
            contacts_with_devices = {r[0] for r in rows}

        snapshots = []
        for contact_id, rels in contact_rels.items():
            contact = contacts_map.get(contact_id)
            if not contact:
                continue

            # Determine permissions for current_user to view contact's data
            # current_user must be the caregiver of the contact, and that specific relationship must allow it.
            can_view_vitals = any(
                (
                    r.caregiver_id == current_user.id
                    and bool(getattr(r, "can_view_vitals", False))
                )
                for r in rels
            )

            viewer_rel = next((r for r in rels if r.caregiver_id == current_user.id), None)
            if not viewer_rel:
                viewer_rel = next((r for r in rels if r.patient_id == current_user.id), rels[0])

            active_sos = latest_active_sos_by_user.get(contact.id)

            # Fetch live monitoring data only when the viewer currently has vitals access.
            sys, dia, hr, spo2, temp = None, None, 0, 0, None
            last_updated = datetime.now(UTC)
            has_vitals_data = False
            vitals_data_message = None
            risk_level = "low"
            sleep_duration_minutes = 0
            sleep_quality = "Trung bình"
            # None until we read a real health_report below; preserves the
            # distinction between 'no data' and a real score of 0 (critical).
            health_score_7_days: int | None = None
            health_score_level = "Trung bình"
            special_note = ""

            if can_view_vitals:
                try:
                    vitals = MonitoringService.get_latest_vital_signs(contact.id, db)
                except Exception:
                    vitals = None

                if vitals is not None:
                    has_vitals_data = True
                    sys = int(vitals.blood_pressure_sys) if vitals.blood_pressure_sys else None
                    dia = int(vitals.blood_pressure_dia) if vitals.blood_pressure_dia else None
                    hr = int(vitals.heart_rate) if vitals.heart_rate else 0
                    spo2 = int(vitals.spo2) if vitals.spo2 else 0
                    temp_value = getattr(vitals, "temperature", None)
                    if temp_value is None:
                        temp_value = getattr(vitals, "body_temperature", None)
                    temp = float(temp_value) if temp_value is not None else None
                    if vitals.timestamp:
                        last_updated = vitals.timestamp
                else:
                    vitals_data_message = RelationshipService._family_vitals_unavailable_message(
                        db,
                        contact.id,
                        has_device=contact.id in contacts_with_devices,
                    )

                sleep_session = MonitoringService.get_latest_sleep_session(contact.id, db)
                if sleep_session is not None:
                    sleep_duration_minutes = sleep_session.sleep_minutes
                    sleep_quality = RelationshipService._family_sleep_quality_label(
                        sleep_session.quality_label,
                    )

                try:
                    health_report = MonitoringService.get_health_report(contact.id, db)
                except Exception:
                    health_report = None

                if health_report is not None:
                    if health_report.risk_level:
                        risk_level = health_report.risk_level
                    if health_report.health_score is not None:
                        health_score_7_days = int(round(float(health_report.health_score)))
                    health_score_level = RelationshipService._family_health_level_label(
                        health_report.health_level,
                    )
                    if health_report.last_updated is not None:
                        last_updated = health_report.last_updated
                    if risk_level == "critical":
                        special_note = (
                            health_report.health_summary
                            or "Sức khỏe hôm nay đang ở mức cần cảnh báo cao."
                        )
                    elif risk_level == "medium":
                        special_note = (
                            health_report.health_summary
                            or "Sức khỏe hôm nay cần được theo dõi thêm."
                        )
            else:
                vitals_data_message = RelationshipService._family_vitals_unavailable_message(
                    db,
                    contact.id,
                    has_device=contact.id in contacts_with_devices,
                )

            if active_sos is not None:
                risk_level = "critical" if risk_level == "low" else risk_level
                special_note = "Cần hỗ trợ ngay!"
                if getattr(active_sos, "triggered_at", None) is not None:
                    last_updated = active_sos.triggered_at

            snapshot = FamilyProfileSnapshot(
                id=str(contact.id),
                name=contact.full_name.split(" ")[-1] if contact.full_name else "Name",
                relation=(
                    viewer_rel.primary_relationship_label
                    if viewer_rel.primary_relationship_label
                    else viewer_rel.relationship_type
                ),
                heart_rate=hr,
                spo2=spo2,
                blood_pressure_systolic=sys,
                blood_pressure_diastolic=dia,
                body_temperature=temp,
                risk_level=risk_level,
                is_sos_active=active_sos is not None,
                sos_id=str(active_sos.id) if active_sos is not None else None,
                has_view_vitals_permission=can_view_vitals,
                has_vitals_data=has_vitals_data,
                vitals_data_message=vitals_data_message,
                is_pinned=bool(viewer_rel.is_primary),
                last_updated=last_updated,
                special_note=special_note,
                sleep_duration_minutes=sleep_duration_minutes,
                sleep_quality=sleep_quality,
                health_score_7_days=health_score_7_days,
                health_score_level=health_score_level,
            )
            snapshots.append(snapshot)

        return snapshots

    @staticmethod
    def get_linked_contact_detail(db: Session, current_user: User, contact_id: int) -> dict:
        relationships = RelationshipRepository.get_user_relationships(db, current_user.id)
        
        # Check if contact_id refers to a target user directly
        rels = [r for r in relationships if r.status == "accepted" and (r.patient_id == contact_id or r.caregiver_id == contact_id)]
        real_contact_id = contact_id
        
        # Fallback: maybe contact_id is actually relationship_id
        if not rels:
            rel_by_id = next((r for r in relationships if r.status == "accepted" and r.id == contact_id), None)
            if rel_by_id:
                real_contact_id = rel_by_id.caregiver_id if rel_by_id.patient_id == current_user.id else rel_by_id.patient_id
                rels = [r for r in relationships if r.status == "accepted" and (r.patient_id == real_contact_id or r.caregiver_id == real_contact_id)]

        if not rels:
            raise HTTPException(status_code=404, detail="Không tìm thấy dữ liệu liên hệ này")

        contact = UserRepository.get_by_id(db, real_contact_id)
        if not contact:
            raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản liên hệ")

        primary_rel = next((r for r in rels if r.patient_id == current_user.id), rels[0])

        permissions = []
        # P-4 added ``can_view_medical_info`` to the trio. Each entry is
        # a permission the *partner* holds against the *current user*
        # ("của tôi"), so we always check rows where current_user is the
        # patient — same gating shape as the other three flags.
        for p in [
            'can_view_vitals',
            'can_receive_alerts',
            'can_view_location',
            'can_view_medical_info',
        ]:
            if any((r.patient_id == current_user.id and getattr(r, p, False)) for r in rels):
                permissions.append(p)

        tags = primary_rel.tags if isinstance(primary_rel.tags, list) else []
        role_label = primary_rel.relationship_type if primary_rel.relationship_type else 'unclassified'

        # Bug fix G-5: see ``format_relationships`` for the full rationale.
        # ``primaryRelationshipLabel`` must come from the row where the
        # current user is the caregiver, otherwise the contact-detail card
        # shows what the partner labelled the current user with.
        caregiver_side_rel = next(
            (r for r in rels if r.caregiver_id == current_user.id),
            None,
        )
        display_label = (
            caregiver_side_rel.primary_relationship_label
            if caregiver_side_rel is not None
            else primary_rel.primary_relationship_label
        )

        return {
            "id": str(primary_rel.id),
            "displayName": contact.full_name or "Người dùng",
            "email": contact.email,
            "avatarUrl": contact.avatar_url or "",
            "primaryRelationshipLabel": display_label,
            "tags": tags,
            "role": role_label,
            "status": primary_rel.status,
            "permissions": permissions,
            "isIncomingRequest": False
        }

    @staticmethod
    def get_linked_contact_medical_info(
        db: Session, current_user: User, contact_id: int
    ) -> dict:
        """P-4: return ``contact_id``'s self-filled medical profile when
        the patient (= ``contact_id``) granted ``can_view_medical_info`` to
        the requesting caregiver (= ``current_user``).

        Permission shape: we look for a row where ``patient_id ==
        contact_id`` *and* ``caregiver_id == current_user.id`` *and*
        ``can_view_medical_info == True``. This mirrors how
        ``get_linked_contact_detail`` reads the trio — the granter is
        always the patient on the row.

        Errors:
            * 404 if no accepted relationship exists in either direction.
            * 403 if the relationship exists but the medical_info bit is off.
            * 404 if ``contact_id`` resolves to a deleted user.
        """

        relationships = RelationshipRepository.get_user_relationships(
            db, current_user.id
        )

        # Mirror ``get_linked_contact_detail``'s contact_id resolution so
        # callers can pass either a real user_id or a relationship_id and
        # get the same UX behaviour.
        rels = [
            r
            for r in relationships
            if r.status == "accepted"
            and (r.patient_id == contact_id or r.caregiver_id == contact_id)
        ]
        real_contact_id = contact_id
        if not rels:
            rel_by_id = next(
                (
                    r
                    for r in relationships
                    if r.status == "accepted" and r.id == contact_id
                ),
                None,
            )
            if rel_by_id:
                real_contact_id = (
                    rel_by_id.caregiver_id
                    if rel_by_id.patient_id == current_user.id
                    else rel_by_id.patient_id
                )
                rels = [
                    r
                    for r in relationships
                    if r.status == "accepted"
                    and (
                        r.patient_id == real_contact_id
                        or r.caregiver_id == real_contact_id
                    )
                ]

        if not rels:
            raise HTTPException(
                status_code=404,
                detail="Không tìm thấy dữ liệu liên hệ này",
            )

        contact = UserRepository.get_by_id(db, real_contact_id)
        if not contact:
            raise HTTPException(
                status_code=404,
                detail="Không tìm thấy tài khoản liên hệ",
            )

        # Gating: the row that authorises caregiver access is the one where
        # ``contact`` is the patient and ``current_user`` is the caregiver.
        # Looking at any other row would let A read B's medical info just
        # because B granted A vitals access on the inverse direction.
        granting_rel = next(
            (
                r
                for r in rels
                if r.patient_id == real_contact_id
                and r.caregiver_id == current_user.id
                and getattr(r, "can_view_medical_info", False)
            ),
            None,
        )
        if granting_rel is None:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Người này chưa cho phép bạn xem hồ sơ y tế. "
                    "Hãy yêu cầu họ bật quyền 'Cho phép xem hồ sơ y tế' "
                    "trong cài đặt liên hệ."
                ),
            )

        # ARRAY columns surface as Python lists already; coerce defensively
        # for legacy rows that may have ``None`` from pre-migration snapshots.
        return {
            "contact_id": contact.id,
            "display_name": contact.full_name or "Người dùng",
            "blood_type": contact.blood_type,
            "height_cm": contact.height_cm,
            "weight_kg": contact.weight_kg,
            "medications": list(contact.medications or []),
            "allergies": list(contact.allergies or []),
            "medical_conditions": list(contact.medical_conditions or []),
        }

