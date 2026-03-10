"""
Script to create mock SOS events for testing Emergency module.
Run this after backend is running with: python -m app.scripts.create_mock_sos_data
"""

from datetime import datetime, timedelta
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from app.models.sos_event_model import SOSEvent, FallEvent
from app.models.user_model import User
from app.models.device_model import Device
from app.db.database import Base, engine, SessionLocal


def create_mock_data():
    """Create mock SOS events for testing."""
    
    # Use existing database session
    db = SessionLocal()
    
    try:
        # Ensure tables exist
        Base.metadata.create_all(bind=engine)
        
        # Get first user as patient (or create one)
        patient = db.query(User).filter(User.role == 'patient').first()
        if not patient:
            print("❌ No patient found in database. Please create a user with role='patient' first.")
            return
        
        print(f"✓ Using patient: {patient.full_name} (ID: {patient.id})")
        
        # Get or create a mock device for the patient
        device = db.query(Device).filter(Device.user_id == patient.id).first()
        if not device:
            device = Device(
                user_id=patient.id,
                device_name="Mock Smartwatch",
                device_type="smartwatch",
                model="SW-001",
                is_active=True,
                battery_level=85
            )
            db.add(device)
            db.commit()
            db.refresh(device)
            print(f"✓ Created mock device (ID: {device.id})")
        else:
            print(f"✓ Using existing device (ID: {device.id})")
        
        device_id = device.id
        
        # Create 3 mock SOS events
        mock_sos_events = [
            {
                "user_id": patient.id,
                "device_id": device_id,
                "trigger_type": "auto",
                "triggered_at": datetime.utcnow() - timedelta(minutes=15),
                "latitude": 21.028511,
                "longitude": 105.804817,
                "address": "Hoàn Kiếm, Hà Nội, Việt Nam",
                "status": "active",
            },
            {
                "user_id": patient.id,
                "device_id": device_id,
                "trigger_type": "manual",
                "triggered_at": datetime.utcnow() - timedelta(hours=2),
                "latitude": 21.027764,
                "longitude": 105.834160,
                "address": "Hai Bà Trưng, Hà Nội, Việt Nam",
                "status": "active",
            },
            {
                "user_id": patient.id,
                "device_id": device_id,
                "trigger_type": "auto",
                "triggered_at": datetime.utcnow() - timedelta(hours=24),
                "latitude": 21.022736,
                "longitude": 105.819355,
                "address": "Ba Đình, Hà Nội, Việt Nam",
                "status": "resolved",
                "resolved_at": datetime.utcnow() - timedelta(hours=23, minutes=45),
                "resolution_notes": "[safe] Người chăm sóc đã xác nhận bệnh nhân an toàn",
            },
        ]
        
        created_count = 0
        for sos_data in mock_sos_events:
            sos = SOSEvent(**sos_data)
            db.add(sos)
            created_count += 1
        
        db.commit()
        
        print(f"\n✅ Created {created_count} mock SOS events successfully!")
        print("\nYou can now test the Emergency API endpoints:")
        print("  GET /api/v1/mobile/caregiver/sos-alerts?status=all")
        print("  GET /api/v1/mobile/emergency/sos/{sos_id}")
        print("  POST /api/v1/mobile/emergency/sos/{sos_id}/resolve")
        
    except Exception as e:
        print(f"❌ Error creating mock data: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    print("Creating mock SOS data...\n")
    create_mock_data()
