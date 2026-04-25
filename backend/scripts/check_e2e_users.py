"""Verify the seeded E2E users + their relationship are present.

Run with the backend venv from `backend/`:
    .\venv\Scripts\python.exe scripts\check_e2e_users.py
"""

from __future__ import annotations

from sqlalchemy import create_engine, text

from app.core.config import settings


PATIENT_EMAIL = "e2e.dashboard.patient@example.com"
CAREGIVER_EMAIL = "e2e.dashboard.caregiver@example.com"


def main() -> None:
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        users = conn.execute(
            text(
                "SELECT id, email, role, is_active, is_verified "
                "FROM users WHERE email = ANY(:emails)"
            ),
            {"emails": [PATIENT_EMAIL, CAREGIVER_EMAIL]},
        ).mappings().all()
        print("== users ==")
        for row in users:
            print(dict(row))

        if len(users) < 2:
            print("MISSING one or both seeded e2e users")
            return

        ids = {row["email"]: row["id"] for row in users}
        rels = conn.execute(
            text(
                "SELECT id, patient_id, caregiver_id, status, can_receive_alerts, can_view_vitals, can_view_location "
                "FROM user_relationships "
                "WHERE patient_id = :patient_id AND caregiver_id = :caregiver_id"
            ),
            {
                "patient_id": ids[PATIENT_EMAIL],
                "caregiver_id": ids[CAREGIVER_EMAIL],
            },
        ).mappings().all()
        print("== relationship ==")
        for row in rels:
            print(dict(row))

        devices = conn.execute(
            text(
                "SELECT id, user_id, device_name, is_active, deleted_at "
                "FROM devices WHERE user_id = :patient_id"
            ),
            {"patient_id": ids[PATIENT_EMAIL]},
        ).mappings().all()
        print("== patient devices ==")
        for row in devices:
            print(dict(row))


if __name__ == "__main__":
    main()
