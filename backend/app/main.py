from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.api.router import api_router
from app.db.database import Base, engine
from app.models.audit_log_model import AuditLog  # noqa: F401 - needed for table creation
from app.models.user_model import User  # noqa: F401 - needed for table creation
from app.models.device_model import Device  # noqa: F401 - needed for table creation
from app.models.sos_event_model import Alert, FallEvent, SOSEvent  # noqa: F401 - needed for table creation
from app.models.relationship_model import UserRelationship  # noqa: F401 - needed for table creation

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Health Guard - Mobile Backend",
    version="0.1.0",
    root_path="/api/v1",
    docs_url="/mobile-docs",
    redoc_url="/mobile-redoc",
    openapi_url="/mobile-openapi.json",
    servers=[
        {"url": "/api/v1", "description": "API v1"},
    ]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/", include_in_schema=False)
def root_redirect():
    """Redirect root URL to Swagger docs"""
    return RedirectResponse(url="/mobile-docs")

