from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.router import api_router
from app.core.config import settings
from app.core.risk_contract import (
    RISK_CONTRACT_VERSION,
    RISK_CONTRACT_VERSION_HEADER,
    applies_to_path,
)
from app.db.database import Base, engine
from app.models.audit_log_model import AuditLog  # noqa: F401 - needed for table creation
from app.models.user_model import User  # noqa: F401 - needed for table creation
from app.models.device_model import Device  # noqa: F401 - needed for table creation
from app.models.notification_read_model import NotificationRead  # noqa: F401 - needed for table creation
from app.models.push_token_model import UserPushToken  # noqa: F401 - needed for table creation
from app.models.sos_event_model import Alert, FallEvent, SOSEvent  # noqa: F401 - needed for table creation
from app.models.relationship_model import UserRelationship  # noqa: F401 - needed for table creation

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Health Guard - Mobile Backend",
    version="0.1.0",
    docs_url="/mobile-docs",
    redoc_url="/mobile-redoc",
    openapi_url="/mobile-openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    # Expose the contract version header so browser clients (e.g. the
    # Swagger UI on /mobile-docs) can read it. Without this CORS strips
    # custom response headers from JS contexts.
    expose_headers=[RISK_CONTRACT_VERSION_HEADER],
)


class RiskContractVersionMiddleware(BaseHTTPMiddleware):
    """Inject ``X-Risk-Contract-Version`` on the mobile risk surface.

    Phase 6: tags every response from
    :data:`app.core.risk_contract.RISK_CONTRACT_ROUTE_PREFIXES` with the
    current contract version so the mobile ``ApiClient`` can detect a
    binary-vs-backend mismatch and surface a debug warning.
    """

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        if applies_to_path(request.url.path):
            response.headers[RISK_CONTRACT_VERSION_HEADER] = RISK_CONTRACT_VERSION
        return response


app.add_middleware(RiskContractVersionMiddleware)

app.include_router(api_router)


@app.get("/", include_in_schema=False)
def root_redirect():
    """Redirect root URL to Swagger docs"""
    return RedirectResponse(url="/mobile-docs")

