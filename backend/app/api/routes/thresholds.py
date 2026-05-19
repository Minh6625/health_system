"""Threshold endpoint — single-source-of-truth for mobile + simulator UI.

Phase 0.1 of the IoT pipeline fix plan: project clinical thresholds from
``backend/app/data/rules_config.json`` into a stable JSON contract so
mobile (Flutter ``ThresholdService``) and the IoT sim-web dashboard can
fetch one document instead of duplicating constants in three places.

The endpoint is anonymous — no auth required — because thresholds are
non-sensitive clinical reference values used to colour vital cards. A
caregiver staring at a "warning" pill needs to know what 'warning'
means; gating that behind login adds friction without security value.
"""

from __future__ import annotations

from fastapi import APIRouter

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
    get_rules_version,
    get_vital_thresholds,
)

router = APIRouter(prefix="/settings", tags=["mobile-thresholds"])


@router.get(
    "/thresholds",
    response_model=ThresholdConfigResponse,
    summary="Clinical thresholds (single source of truth)",
)
def get_thresholds() -> ThresholdConfigResponse:
    """Return the projected vitals + model + fall thresholds.

    Cached server-side via ``threshold_loader._CACHE`` (mtime-keyed) so
    repeated polling from many clients is cheap. Mobile clients should
    fetch once per app launch and persist locally; the contract is
    stable but the values may shift between releases (bump
    ``snapshot_version`` to invalidate client caches).
    """
    vitals_dict = get_vital_thresholds()
    vitals = VitalsThresholds(
        heart_rate=HeartRateThresholds(**vitals_dict["heart_rate"]),
        spo2=Spo2Thresholds(**vitals_dict["spo2"]),
        body_temp=BodyTempThresholds(**vitals_dict["body_temp"]),
        resp_rate=RespRateThresholds(**vitals_dict["resp_rate"]),
        sys_bp=SysBpThresholds(**vitals_dict["sys_bp"]),
        dia_bp=DiaBpThresholds(**vitals_dict["dia_bp"]),
    )
    return ThresholdConfigResponse(
        version=get_rules_version(),
        snapshot_version=SNAPSHOT_VERSION,
        vitals=vitals,
        # Aligns with PR-3 P1-6: lowered to 0.5 (model-api fall_true_at)
        # so the BE secondary-validation gate matches what the model
        # already considers "fall positive". Variant fall_brief (0.65)
        # now produces a soft alert instead of being silently dropped.
        fall_confidence_threshold=0.5,
        model_thresholds=ModelThresholds(
            health=ModelHealthThresholds(),
            fall=ModelFallThresholds(),
            sleep=ModelSleepThresholds(),
        ),
    )
