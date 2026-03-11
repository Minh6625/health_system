from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.api.router import api_router
from app.db.database import Base, engine
from app.models.audit_log_model import AuditLog  # noqa: F401 - needed for table creation
from app.models.user_model import User  # noqa: F401 - needed for table creation
from app.models.device_model import Device  # noqa: F401 - needed for table creation
from app.models.sos_event_model import FallEvent, SOSEvent  # noqa: F401 - needed for table creation

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Health System Backend", version="0.1.0")

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
    return RedirectResponse(url="/docs")

