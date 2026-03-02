import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://postgres:123456@localhost:5433/health_system")
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    # Access token expiry in days (30 days = 43200 minutes)
    ACCESS_TOKEN_EXPIRE_DAYS: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_DAYS", 30))


settings = Settings()
