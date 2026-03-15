from app.db.database import SessionLocal
from sqlalchemy import text

db = SessionLocal()
try:
    db.execute(text("UPDATE user_relationships SET status = 'accepted'"))
    db.commit()
    print("Updated existing records to accepted")
except Exception as e:
    print("Error:", e)
finally:
    db.close()
