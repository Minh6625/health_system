from typing import List, Dict, Any
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
        for rel in linked_relationships:
            patient = UserRepository.get_by_id(db, rel.patient_id)
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
            
        if not target_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy người dùng với thông tin này"
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
        
        # Check if inverse relationship already exists
        existing_inverse_rel = db.query(UserRelationship).filter(
            UserRelationship.patient_id == rel.caregiver_id,
            UserRelationship.caregiver_id == rel.patient_id
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
                can_view_location=False
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

    @staticmethod
    def update_relationship(db: Session, current_user: User, relationship_id: int, payload: Any) -> UserRelationship:
        rel = RelationshipRepository.get_by_id(db, relationship_id)
        if not rel:
            raise HTTPException(status_code=404, detail="Không tìm thấy liên kết")
            
        if rel.patient_id != current_user.id and rel.caregiver_id != current_user.id:
            raise HTTPException(status_code=403, detail="Không có quyền cập nhật liên kết này")
            
        update_data = payload.dict(exclude_unset=True)
        for key, value in update_data.items():
            setattr(rel, key, value)

        return RelationshipRepository.update(db, rel)

    @staticmethod
    def format_relationships(db: Session, user_id: int) -> List[Dict[str, Any]]:
        rels = db.query(UserRelationship).filter(
            (UserRelationship.patient_id == user_id) | 
            (UserRelationship.caregiver_id == user_id)
        ).all()
        
        # Group by partner_id
        grouped = {}
        for r in rels:
            partner_id = r.caregiver_id if r.patient_id == user_id else r.patient_id
            if partner_id not in grouped:
                grouped[partner_id] = []
            grouped[partner_id].append(r)
            
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
                
            patient = UserRepository.get_by_id(db, primary_rel.patient_id)
            caregiver = UserRepository.get_by_id(db, primary_rel.caregiver_id)
            if not patient or not caregiver:
                continue
                
            inverse_rel = next((r for r in partner_rels if r.caregiver_id == user_id), None)
            
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
                "primary_relationship_label": primary_rel.primary_relationship_label,
                "tags": primary_rel.tags if primary_rel.tags else [],
                "can_view_vitals": primary_rel.can_view_vitals,
                "can_receive_alerts": primary_rel.can_receive_alerts,
                "can_view_location": primary_rel.can_view_location,
                "created_at": primary_rel.created_at
            }
            
            if inverse_rel:
                res_dict["has_view_vitals_permission"] = inverse_rel.can_view_vitals
                res_dict["has_receive_alerts_permission"] = inverse_rel.can_receive_alerts
                res_dict["has_view_location_permission"] = inverse_rel.can_view_location
            else:
                res_dict["has_view_vitals_permission"] = False
                res_dict["has_receive_alerts_permission"] = False
                res_dict["has_view_location_permission"] = False
                
            result.append(res_dict)
            
        return result
    @staticmethod
    def get_dashboard_snapshots(db: Session, current_user: User) -> List[Any]:
        from app.services.monitoring_service import MonitoringService
        from app.schemas.relationship import FamilyProfileSnapshot
        from datetime import datetime, UTC

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

        snapshots = []
        for contact_id, rels in contact_rels.items():
            contact = UserRepository.get_by_id(db, contact_id)
            if not contact:
                continue

            # Determine permissions for current_user to view contact's data
            # current_user must be the caregiver of the contact, and that specific relationship must allow it.
            can_view_vitals = any((r.caregiver_id == current_user.id and getattr(r, 'can_view_vitals', False)) for r in rels)

            # Setup detail label. Prefer the relationship where current_user is patient
            rel = next((r for r in rels if r.patient_id == current_user.id), rels[0])

            # Fetch vitals
            sys, dia, hr, spo2, temp = None, None, 0, 0, None
            last_updated = datetime.now(UTC)
            has_vitals_data = True
            vitals_data_message = None
            try:
                vitals = MonitoringService.get_latest_vital_signs(contact.id, db)
                if hasattr(vitals, "blood_pressure_sys"):
                    sys = int(vitals.blood_pressure_sys) if vitals.blood_pressure_sys else None
                    dia = int(vitals.blood_pressure_dia) if vitals.blood_pressure_dia else None
                    hr = int(vitals.heart_rate) if vitals.heart_rate else 0 
                    spo2 = int(vitals.spo2) if vitals.spo2 else 0
                    temp = float(vitals.body_temperature) if vitals.body_temperature else None
                    if vitals.timestamp:
                        last_updated = vitals.timestamp
            except Exception:
                has_vitals_data = False
                has_device = db.execute(
                    text(
                        """
                        SELECT 1
                        FROM devices
                        WHERE user_id = :user_id
                        LIMIT 1
                        """
                    ),
                    {"user_id": contact.id},
                ).first() is not None

                if has_device:
                    vitals_data_message = "Thiết bị đã kết nối nhưng chưa có dữ liệu đo."
                else:
                    vitals_data_message = "Người dùng chưa kết nối thiết bị với tài khoản."

            snapshot = FamilyProfileSnapshot(
                id=str(contact.id),
                name=contact.full_name.split(" ")[-1] if contact.full_name else "Name",
                relation=rel.primary_relationship_label if rel.primary_relationship_label else rel.relationship_type,
                heart_rate=hr,
                spo2=spo2,
                blood_pressure_systolic=sys,
                blood_pressure_diastolic=dia,
                body_temperature=temp,
                risk_level="low",
                is_sos_active=False,
                has_view_vitals_permission=can_view_vitals,
                has_vitals_data=has_vitals_data,
                vitals_data_message=vitals_data_message,
                is_pinned=False,
                last_updated=last_updated
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
        for p in ['can_view_vitals', 'can_receive_alerts', 'can_view_location']:
            # The permissions here refer to what the OTHER person can do to CURRENT user ("của tôi")
            # So we check the row where current_user is the patient.
            if any((r.patient_id == current_user.id and getattr(r, p, False)) for r in rels):
                permissions.append(p)

        tags = primary_rel.tags if isinstance(primary_rel.tags, list) else []
        role_label = primary_rel.relationship_type if primary_rel.relationship_type else 'unclassified'

        return {
            "id": str(primary_rel.id),
            "displayName": contact.full_name or "Người dùng",
            "email": contact.email,
            "avatarUrl": contact.avatar_url or "",
            "primaryRelationshipLabel": primary_rel.primary_relationship_label,
            "tags": tags,
            "role": role_label,
            "status": primary_rel.status,
            "permissions": permissions,
            "isIncomingRequest": False
        }

