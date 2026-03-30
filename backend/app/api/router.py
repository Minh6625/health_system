from fastapi import APIRouter

from app.api.routes.admin import router as admin_router
from app.api.routes.auth import router as auth_router
from app.api.routes.device import router as device_router
from app.api.routes.emergency import router as emergency_router
from app.api.routes.health import router as health_router
from app.api.routes.monitoring import router as monitoring_router
from app.api.routes.profile import router as profile_router
from app.api.routes.relationships import router as relationships_router
from app.api.routes.risk import router as risk_router
from app.api.routes.telemetry import router as telemetry_router

api_router = APIRouter(prefix="/mobile")
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(emergency_router)
api_router.include_router(monitoring_router)
api_router.include_router(risk_router)
api_router.include_router(telemetry_router)
api_router.include_router(device_router)
api_router.include_router(admin_router)
api_router.include_router(profile_router)
api_router.include_router(relationships_router)
