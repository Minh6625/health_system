from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

from app.models.relationship_model import UserRelationship
from app.models.user_model import User

class RelationshipRepository:
    @staticmethod
    def get_by_id(db: Session, relationship_id: int) -> Optional[UserRelationship]:
        return db.query(UserRelationship).filter(UserRelationship.id == relationship_id).first()

    @staticmethod
    def get_user_relationships(db: Session, user_id: int) -> List[UserRelationship]:
        return db.query(UserRelationship).filter(
            or_(
                UserRelationship.patient_id == user_id,
                UserRelationship.caregiver_id == user_id
            )
        ).all()
        
    @staticmethod
    def get_viewable_profiles(db: Session, caregiver_id: int) -> List[UserRelationship]:
        return db.query(UserRelationship).filter(
            UserRelationship.caregiver_id == caregiver_id,
            UserRelationship.status == 'accepted',
            or_(
                UserRelationship.can_view_vitals == True,
                UserRelationship.can_receive_alerts == True,
                UserRelationship.can_view_location == True,
            ),
        ).all()

    @staticmethod
    def get_pending_requests(db: Session, user_id: int) -> List[UserRelationship]:
        return db.query(UserRelationship).filter(
            UserRelationship.patient_id == user_id,
            UserRelationship.status == 'pending'
        ).all()

    @staticmethod
    def create(db: Session, relationship: UserRelationship) -> UserRelationship:
        db.add(relationship)
        db.commit()
        db.refresh(relationship)
        return relationship

    @staticmethod
    def update(db: Session, relationship: UserRelationship) -> UserRelationship:
        db.commit()
        db.refresh(relationship)
        return relationship

    @staticmethod
    def delete(db: Session, relationship: UserRelationship) -> None:
        db.delete(relationship)
        db.commit()
