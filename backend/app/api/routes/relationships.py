from fastapi import APIRouter, Depends, HTTPException, Request, status
from typing import List
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.dependencies import get_current_user
from app.models.user_model import User
from app.schemas.relationship import (
    AccessProfileResponse,
    FamilyProfileSnapshot,
    LinkedContactDetailResponse,
    LinkedContactMedicalInfoResponse,
    RelationshipAcceptRequest,
    RelationshipRequestCreate,
    RelationshipResponse,
    RelationshipUpdate,
    UserSearchResponse,
)
from app.services.relationship_service import RelationshipService
from app.utils.audit_helper import get_client_ip, get_user_agent, safe_log_action

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
    response_model=LinkedContactDetailResponse,
    summary="Get detail health data of a linked contact"
)
def get_linked_contact_detail(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return RelationshipService.get_linked_contact_detail(db, current_user, contact_id)


@router.get(
    "/relationships/{contact_id}/medical-info",
    response_model=LinkedContactMedicalInfoResponse,
    summary="Get a linked contact's self-filled medical profile",
)
def get_linked_contact_medical_info(
    contact_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """P-4: read the patient's medical info when they granted
    ``can_view_medical_info`` to the current caregiver. Returns 403 if
    the bit is off, 404 if no relationship exists."""
    return RelationshipService.get_linked_contact_medical_info(
        db, current_user, contact_id
    )

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
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send a request to a family member or friend by email/phone"""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)
    try:
        rel = RelationshipService.request_relationship(db, current_user, payload)
    except HTTPException as exc:
        # 404 (target not found) is enumeration-resistant — skip audit.
        # All other 4xx (self-link, account inactive, duplicate) ARE worth
        # auditing because they reveal social-engineering attempts.
        if exc.status_code != status.HTTP_404_NOT_FOUND:
            safe_log_action(
                db,
                action="relationship.requested",
                status="failure",
                user_id=int(current_user.id),
                resource_type="relationship",
                ip_address=ip_address,
                user_agent=user_agent,
                details={
                    "reason": str(exc.detail),
                    "http_status": exc.status_code,
                    "target_user_id": payload.target_user_id,
                    "has_email": bool(payload.email),
                    "has_phone": bool(payload.phone),
                },
            )
        raise
    safe_log_action(
        db,
        action="relationship.requested",
        status="success",
        user_id=int(current_user.id),
        resource_type="relationship",
        resource_id=int(rel.id),
        ip_address=ip_address,
        user_agent=user_agent,
        details={
            "target_user_id": int(rel.patient_id)
            if rel.caregiver_id == current_user.id
            else int(rel.caregiver_id),
            "relationship_type": getattr(rel, "relationship_type", None),
        },
    )
    all_rels = RelationshipService.format_relationships(db, current_user.id)
    for r in all_rels:
        if r["id"] == rel.id:
            return r
    return all_rels[-1]  # fallback


@router.post(
    "/relationships/accept",
    response_model=RelationshipResponse,
    summary="Accept a relationship request"
)
def accept_relationship(
    payload: RelationshipAcceptRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Accept an incoming request from someone wanting to view your data"""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)
    try:
        rel = RelationshipService.accept_relationship(db, current_user, payload.relationship_id)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_403_FORBIDDEN:
            safe_log_action(
                db,
                action="relationship.accepted",
                status="failure",
                user_id=int(current_user.id),
                resource_type="relationship",
                resource_id=int(payload.relationship_id),
                ip_address=ip_address,
                user_agent=user_agent,
                details={"reason": "forbidden"},
            )
        raise
    safe_log_action(
        db,
        action="relationship.accepted",
        status="success",
        user_id=int(current_user.id),
        resource_type="relationship",
        resource_id=int(rel.id),
        ip_address=ip_address,
        user_agent=user_agent,
        details={
            "patient_id": int(rel.patient_id),
            "caregiver_id": int(rel.caregiver_id),
            "relationship_type": getattr(rel, "relationship_type", None),
        },
    )
    rels = RelationshipService.format_relationships(db, current_user.id)
    for r in rels:
        if r["id"] == rel.id:
            return r
    raise HTTPException(status_code=404, detail="Relationship not found after accept")

@router.put(
    "/relationships/{relationship_id}",
    response_model=RelationshipResponse,
    summary="Update relationship permissions and tags"
)
def update_relationship(
    relationship_id: int,
    payload: RelationshipUpdate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update permissions like can_view_vitals, or tags/relationship_type"""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)
    # Snapshot BEFORE the mutation so audit captures the old permission
    # bits. ``None`` means no row exists; the service will raise 404 and
    # we skip the audit log (enumeration-resistant).
    snapshot_before = RelationshipService.get_relationship_snapshot(db, relationship_id)
    try:
        rel = RelationshipService.update_relationship(db, current_user, relationship_id, payload)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_403_FORBIDDEN:
            safe_log_action(
                db,
                action="relationship.updated",
                status="failure",
                user_id=int(current_user.id),
                resource_type="relationship",
                resource_id=int(relationship_id),
                ip_address=ip_address,
                user_agent=user_agent,
                details={
                    "reason": "forbidden",
                    "permissions_before": snapshot_before,
                },
            )
        raise
    snapshot_after = RelationshipService.get_relationship_snapshot(db, relationship_id)
    safe_log_action(
        db,
        action="relationship.updated",
        status="success",
        user_id=int(current_user.id),
        resource_type="relationship",
        resource_id=int(rel.id),
        ip_address=ip_address,
        user_agent=user_agent,
        details={
            "permissions_before": snapshot_before,
            "permissions_after": snapshot_after,
            "fields_changed": list(payload.dict(exclude_unset=True).keys()),
        },
    )
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
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a pending request, or revoke access to an accepted relationship"""
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)
    snapshot_before = RelationshipService.get_relationship_snapshot(db, relationship_id)
    try:
        RelationshipService.delete_relationship(db, current_user, relationship_id)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_403_FORBIDDEN:
            safe_log_action(
                db,
                action="relationship.deleted",
                status="failure",
                user_id=int(current_user.id),
                resource_type="relationship",
                resource_id=int(relationship_id),
                ip_address=ip_address,
                user_agent=user_agent,
                details={
                    "reason": "forbidden",
                    "permissions_before": snapshot_before,
                },
            )
        raise
    safe_log_action(
        db,
        action="relationship.deleted",
        status="success",
        user_id=int(current_user.id),
        resource_type="relationship",
        resource_id=int(relationship_id),
        ip_address=ip_address,
        user_agent=user_agent,
        details={
            "permissions_before": snapshot_before,
        },
    )
