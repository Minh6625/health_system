from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.db.database import Base, engine
from app.models.audit_log_model import AuditLog  # noqa: F401 - needed for table creation
from app.models.user_model import User  # noqa: F401 - needed for table creation

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
