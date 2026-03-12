from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.routes.device import router as device_router
from app.api.routes.emergency import router as emergency_router
from app.api.routes.health import router as health_router
from app.api.routes.monitoring import router as monitoring_router
from app.api.routes.profile import router as profile_router

api_router = APIRouter(prefix="/mobile")
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(emergency_router)
api_router.include_router(monitoring_router)
api_router.include_router(device_router)
api_router.include_router(profile_router)
