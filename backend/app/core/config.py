import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://postgres:88888888@0.tcp.ngrok.io:18304/hg_db")
    
    # Security: SECRET_KEY must be set in environment
    SECRET_KEY: str = os.getenv("SECRET_KEY", "")
    if not SECRET_KEY or SECRET_KEY == "your-secret-key-change-in-production":
        raise ValueError(
            "SECRET_KEY must be set in environment variables (.env file). "
            "Generate a secure key using: openssl rand -hex 32"
        )
    
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    # Access token expiry in days (30 days = 43200 minutes)
    ACCESS_TOKEN_EXPIRE_DAYS: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_DAYS", 30))
    
    # Email configuration
    SMTP_SERVER: str = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SENDER_EMAIL: str = os.getenv("SENDER_EMAIL", "")
    SENDER_PASSWORD: str = os.getenv("SENDER_PASSWORD", "")
    
    # Frontend URL for email verification links (web)
    FRONTEND_URL: str = os.getenv("FRONTEND_URL", "http://localhost:3000")
    
    # Mobile app deep link scheme for email verification/password reset
    MOBILE_DEEP_LINK_SCHEME: str = os.getenv("MOBILE_DEEP_LINK_SCHEME", "healthguard")

settings = Settings()