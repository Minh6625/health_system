from typing import List, Dict, Any
from fastapi import HTTPException, status
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

        return [
            UserSearchResponse(
                id=u.id,
                full_name=u.full_name,
                email=u.email,
                phone=u.phone,
                avatar_url=u.avatar_url
            ) for u in users
        ]
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
            
        # Create as pending
        new_rel = UserRelationship(
            patient_id=target_user.id,        # The one being requested (they must accept)
            caregiver_id=current_user.id,     # The one sending the request (wants to view)
            relationship_type=payload.relationship_type,
            status="pending",
            primary_relationship_label=payload.primary_relationship_label,
            tags=payload.tags if payload.tags else [],
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
            
