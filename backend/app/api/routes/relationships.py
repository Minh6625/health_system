from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.dependencies import get_current_user
from app.models.user_model import User
from app.schemas.relationship import (
    AccessProfileResponse,
    RelationshipRequestCreate,
    RelationshipAcceptRequest,
    RelationshipUpdate,
    RelationshipResponse,
    UserSearchResponse,
    FamilyProfileSnapshot
)
from app.services.relationship_service import RelationshipService

router = APIRouter(tags=["mobile-relationships"])

@router.get(
    "/relationships/dashboard",
    response_model=List[FamilyProfileSnapshot],
    summary="Get family monitoring dashboard metrics"
)
def get_family_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retrieve realtime vital snapshot list for the current users relatives."""
    return RelationshipService.get_dashboard_snapshots(db, current_user)

@router.get(
    "/relationships/{contact_id}/detail",
    response_model=dict,
    summary="Get detail health data of a linked contact"
)
def get_linked_contact_detail(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """View the dashboard stats of a specific tracked person."""
    return RelationshipService.get_linked_contact_detail(db, current_user, contact_id)

@router.get(
    "/access-profiles",
    response_model=List[AccessProfileResponse],
    summary="Get list of access profiles"
)
def get_access_profiles(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> List[AccessProfileResponse]:
    """Retrieve all profiles the current user has access to view (including themselves)"""
    return RelationshipService.get_access_profiles(db, current_user)


@router.get(
    "/relationships/search",
    response_model=List[UserSearchResponse],
    summary="Search for a user by email or phone"
)
def search_users(
    query: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Search for users by email, phone, or name (excluding self)"""
    return RelationshipService.search_users(db, current_user, query)

@router.get(
    "/relationships",
    response_model=List[RelationshipResponse],
    summary="Get all relationships"
)
def get_relationships(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all incoming and outgoing relationships/requests"""
    return RelationshipService.format_relationships(db, current_user.id)


@router.post(
    "/relationships/request",
    response_model=RelationshipResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Send a relationship request"
)
def request_relationship(
    payload: RelationshipRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send a request to a family member or friend by email/phone"""
    rel = RelationshipService.request_relationship(db, current_user, payload)
    return RelationshipService.format_relationships(db, current_user.id)[-1]  # Return fully formatted


@router.post(
    "/relationships/accept",
    response_model=RelationshipResponse,
    summary="Accept a relationship request"
)
def accept_relationship(
    payload: RelationshipAcceptRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Accept an incoming request from someone wanting to view your data"""
    rel = RelationshipService.accept_relationship(db, current_user, payload.relationship_id)
    # Find and return fully formatted
    rels = RelationshipService.format_relationships(db, current_user.id)
    for r in rels:
        if r["id"] == rel.id:
            return r
    raise HTTPException(status_code=404, detail="Error formatting response")

@router.put(
    "/relationships/{relationship_id}",
    response_model=RelationshipResponse,
    summary="Update relationship permissions and tags"
)
def update_relationship(
    relationship_id: int,
    payload: RelationshipUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update permissions like can_view_vitals, or tags/relationship_type"""
    rel = RelationshipService.update_relationship(db, current_user, relationship_id, payload)
    rels = RelationshipService.format_relationships(db, current_user.id)
    for r in rels:
        if r["id"] == rel.id:
            return r
    raise HTTPException(status_code=404, detail="Error formatting response")

@router.delete(
    "/relationships/{relationship_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete or cancel a relationship"
)
def delete_relationship(
    relationship_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a pending request, or revoke access to an accepted relationship"""
    RelationshipService.delete_relationship(db, current_user, relationship_id)
