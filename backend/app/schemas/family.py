"""Family-facing schema aliases.

[HS-014 Phase 4] FamilyProfileSnapshot used to be defined twice (here and in
``relationship.py``) with diverging field sets - 19 fields vs 21 fields with
different ``sleep_quality`` defaults. The relationship.py definition is the
canonical superset (it carries ``has_vitals_data`` + ``vitals_data_message``
flags consumed by RelationshipService and the mobile dashboard route).

This module now re-exports from ``relationship.py`` so a single response
shape is used by every consumer, eliminating the inconsistency. A separate
local ``LinkedContactDetailResponse`` is retained because the existing
shape (daily activity counters) does not collide with the relationship
module's contact detail schema (acquaintance metadata).
"""

from pydantic import BaseModel

from app.schemas.relationship import FamilyProfileSnapshot

__all__ = ["FamilyProfileSnapshot", "LinkedContactDetailResponse"]


class LinkedContactDetailResponse(BaseModel):
    """Daily activity counters surfaced on the family detail screen."""

    id: str
    daily_step_count: int
    daily_distance_km: float
    calories_burned: int
