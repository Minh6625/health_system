"""
DEV ONLY — Script to create a caregiver user for testing Emergency module.

Run with: python -m app.scripts.create_caregiver_user

Required env vars (do not commit values):
    SEED_CAREGIVER_EMAIL — email cho caregiver test account
    SEED_CAREGIVER_PASSWORD — secret cho caregiver test account

Production guard: refuses to run when ENV=production.
"""

from datetime import date
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from app.models.user_model import User
from app.db.database import SessionLocal
from app.services.auth_service import AuthService


def _require_dev_env() -> None:
    env = os.getenv("ENV", "development").lower()
    if env == "production":
        raise RuntimeError(
            "Refusing to run seed script in production (ENV=production). "
            "This script is DEV ONLY."
        )


def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"Missing env var {name}. Set it in .env.dev (gitignored) before running this DEV ONLY script."
        )
    return value


def create_caregiver():
    """Create a caregiver user for testing."""

    _require_dev_env()
    caregiver_email = _require_env("SEED_CAREGIVER_EMAIL")
    caregiver_secret = _require_env("SEED_CAREGIVER_PASSWORD")

    db = SessionLocal()

    try:
        existing_caregiver = db.query(User).filter(User.email == caregiver_email).first()

        if existing_caregiver:
            print(f"Caregiver already exists: {existing_caregiver.email}")
            print(f"  Full name: {existing_caregiver.full_name}")
            print(f"  Role: {existing_caregiver.role}")
            print(f"  User ID: {existing_caregiver.id}")
            print(
                "\nLogin credentials taken from env vars SEED_CAREGIVER_EMAIL / SEED_CAREGIVER_PASSWORD."
            )
            return

        success, message, token_data = AuthService.register(
            db=db,
            email=caregiver_email,
            full_name="Người Chăm Sóc Test",
            password=caregiver_secret,
            role="caregiver",
            date_of_birth=date(1985, 5, 15),
            phone="0901234567",
            ip_address="127.0.0.1",
            user_agent="Script",
        )

        if success:
            user = token_data.get("user")
            print("Created caregiver user successfully!")
            print(f"  Email: {user.email}")
            print(f"  Full name: {user.full_name}")
            print(f"  Role: {user.role}")
            print(f"  User ID: {user.id}")
            print(
                "\nLogin credentials taken from env vars SEED_CAREGIVER_EMAIL / SEED_CAREGIVER_PASSWORD."
            )
        else:
            print(f"Failed to create caregiver: {message}")

    except Exception as e:
        print(f"Error creating caregiver: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    print("Creating caregiver user for testing...\n")
    create_caregiver()
