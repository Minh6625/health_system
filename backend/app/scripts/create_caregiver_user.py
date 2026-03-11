"""
Script to create a caregiver user for testing Emergency module.
Run this with: python -m app.scripts.create_caregiver_user
"""

from datetime import date
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from app.models.user_model import User
from app.db.database import SessionLocal
from app.services.auth_service import AuthService


def create_caregiver():
    """Create a caregiver user for testing."""
    
    db = SessionLocal()
    
    try:
        # Check if caregiver already exists
        existing_caregiver = db.query(User).filter(
            User.email == "caregiver@test.com"
        ).first()
        
        if existing_caregiver:
            print(f"✓ Caregiver already exists: {existing_caregiver.email}")
            print(f"  Full name: {existing_caregiver.full_name}")
            print(f"  Role: {existing_caregiver.role}")
            print(f"  User ID: {existing_caregiver.id}")
            print(f"\nYou can login with:")
            print(f"  Email: caregiver@test.com")
            print(f"  Password: Test@123")
            return
        
        # Create new caregiver user
        success, message, token_data = AuthService.register(
            db=db,
            email="caregiver@test.com",
            full_name="Người Chăm Sóc Test",
            password="Test@123",
            role="caregiver",
            date_of_birth=date(1985, 5, 15),
            phone="0901234567",
            ip_address="127.0.0.1",
            user_agent="Script"
        )
        
        if success:
            user = token_data.get("user")
            print(f"✅ Created caregiver user successfully!")
            print(f"  Email: {user.email}")
            print(f"  Full name: {user.full_name}")
            print(f"  Role: {user.role}")
            print(f"  User ID: {user.id}")
            print(f"\nYou can now login with:")
            print(f"  Email: caregiver@test.com")
            print(f"  Password: Test@123")
        else:
            print(f"❌ Failed to create caregiver: {message}")
        
    except Exception as e:
        print(f"❌ Error creating caregiver: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    print("Creating caregiver user for testing...\n")
    create_caregiver()
