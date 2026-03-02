from sqlalchemy.orm import Session

from app.models.user_model import User
from app.utils.datetime_helper import get_current_time
from app.utils.password import hash_password, verify_password


class UserRepository:
    @staticmethod
    def get_by_email(db: Session, email: str) -> User | None:
        return db.query(User).filter(User.email == email).first()

    @staticmethod
    def get_by_id(db: Session, user_id: int) -> User | None:
        return db.query(User).filter(User.id == user_id).first()

    @staticmethod
    def create_user(db: Session, email: str, password: str, full_name: str) -> User:
        hashed_password = hash_password(password)
        user = User(
            email=email,
            password_hash=hashed_password,
            full_name=full_name or email.split("@")[0],
            role="patient",
            is_active=True,
            is_verified=False,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def verify_login(db: Session, email: str, password: str) -> User | None:
        """
        Verify login credentials.
        Returns User if valid, None if invalid.
        Does NOT check is_active flag - that's done in service layer.
        """
        user = UserRepository.get_by_email(db, email)
        if not user:
            return None
        if not verify_password(password, user.password_hash):
            return None
        return user

    @staticmethod
    def update_last_login(db: Session, user_id: int) -> None:
        """Update user's last_login_at timestamp."""
        user = UserRepository.get_by_id(db, user_id)
        if user:
            user.last_login_at = get_current_time()
            db.commit()

    @staticmethod
    def verify_email(db: Session, user_id: int) -> bool:
        """Mark user's email as verified."""
        user = UserRepository.get_by_id(db, user_id)
        if user:
            user.is_verified = True
            user.updated_at = get_current_time()
            db.commit()
            return True
        return False
