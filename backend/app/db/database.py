import os

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

_pool_size = int(os.getenv("DB_POOL_SIZE", "10"))
_max_overflow = int(os.getenv("DB_MAX_OVERFLOW", "20"))
_pool_timeout = int(os.getenv("DB_POOL_TIMEOUT", "30"))

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=1800,
    pool_size=_pool_size,
    max_overflow=_max_overflow,
    pool_timeout=_pool_timeout,
)


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
