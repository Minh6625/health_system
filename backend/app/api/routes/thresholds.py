"""Threshold endpoint — single-source-of-truth for mobile + simulator UI.

Phase 0.1 of the IoT pipeline fix plan. Reads
``system_settings.clinical_rules_thresholds`` so admin website edits
propagate without redeploy.

The endpoint is anonymous — no auth required — because thresholds are
non-sensitive clinical reference values used to colour vital cards. A
caregiver staring at a "warning" pill needs to know what 'warning'
means; gating that behind login adds friction without security value.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.schemas.general_settings import (
    BodyTempThresholds,
    DiaBpThresholds,
    HeartRateThresholds,
    ModelFallThresholds,
    ModelHealthThresholds,
    ModelSleepThresholds,
    ModelThresholds,
    RespRateThresholds,
    Spo2Thresholds,
    SysBpThresholds,
    ThresholdConfigResponse,
    VitalsThresholds,
)
from app.services.threshold_loader import (
    SNAPSHOT_VERSION,
    get_fall_confidence_threshold,
    get_model_thresholds,
    get_rules_version,
    get_vital_thresholds,
)

router = APIRouter(prefix="/settings", tags=["mobile-thresholds"])


@router.get(
    "/thresholds",
    response_model=ThresholdConfigResponse,
    summary="Clinical thresholds (single source of truth)",
)
def get_thresholds(db: Session = Depends(get_db)) -> ThresholdConfigResponse:
    """Return the clinical vitals + model + fall thresholds.

    Source: ``system_settings.clinical_rules_thresholds`` row. Cached
    server-side via ``threshold_loader._CACHE`` (TTL 300s) so repeated
    polling from many clients stays cheap. Mobile clients should fetch
    once per app launch and persist locally; the contract is stable but
    values may shift between releases (admin updates the row through
    the admin website).
    """
    vitals_dict = get_vital_thresholds(db)
    model_dict = get_model_thresholds(db)
    vitals = VitalsThresholds(
        heart_rate=HeartRateThresholds(**vitals_dict["heart_rate"]),
        spo2=Spo2Thresholds(**vitals_dict["spo2"]),
        body_temp=BodyTempThresholds(**vitals_dict["body_temp"]),
        resp_rate=RespRateThresholds(**vitals_dict["resp_rate"]),
        sys_bp=SysBpThresholds(**vitals_dict["sys_bp"]),
        dia_bp=DiaBpThresholds(**vitals_dict["dia_bp"]),
    )
    return ThresholdConfigResponse(
        version=get_rules_version(db),
        snapshot_version=SNAPSHOT_VERSION,
        vitals=vitals,
        fall_confidence_threshold=get_fall_confidence_threshold(db),
        model_thresholds=ModelThresholds(
            health=ModelHealthThresholds(**model_dict["health"]),
            fall=ModelFallThresholds(**model_dict["fall"]),
            sleep=ModelSleepThresholds(**model_dict["sleep"]),
        ),
    )
