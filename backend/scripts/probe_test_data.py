"""Probe DB for test data needed by the Module FA-2 live E2E.

Reports:

* Users (any) — to find a candidate patient + caregiver pair.
* Devices with user binding — needed for the simulator to address an
  alert at a real ``device_id``.
* Accepted ``user_relationships`` rows — needed for the soft caregiver
  follow-up push to find recipients.
* Active FCM tokens — needed for the BE to actually attempt the FCM
  send (even if FCM credentials are missing, an active token is
  required to reach the messaging.send_each call).
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from sqlalchemy import text  # noqa: E402

from app.db.database import engine  # noqa: E402


def main() -> None:
    with engine.connect() as conn:
        print("=== Users (top 10 by id) ===")
        for row in conn.execute(
            text("SELECT id, email, full_name FROM users ORDER BY id LIMIT 10")
        ).mappings():
            print(
                f"  user={row['id']:>3} email={row['email']:<35} name={row['full_name']}"
            )

        print("\n=== Devices (with user binding, top 10) ===")
        for row in conn.execute(
            text(
                "SELECT id, user_id, serial_number "
                "FROM devices WHERE user_id IS NOT NULL ORDER BY id LIMIT 10"
            )
        ).mappings():
            print(
                f"  device={row['id']:>3} user={row['user_id']:<3} "
                f"serial={row['serial_number']}"
            )

        print("\n=== Accepted relationships (top 10) ===")
        for row in conn.execute(
            text(
                "SELECT id, patient_id, caregiver_id, status, "
                "can_receive_alerts, can_view_location "
                "FROM user_relationships "
                "WHERE status = 'accepted' AND deleted_at IS NULL "
                "ORDER BY id LIMIT 10"
            )
        ).mappings():
            print(
                f"  rel={row['id']:>3} patient={row['patient_id']:<3} "
                f"caregiver={row['caregiver_id']:<3} "
                f"alerts={row['can_receive_alerts']} "
                f"loc={row['can_view_location']}"
            )

        print("\n=== Active FCM tokens (per user) ===")
        for row in conn.execute(
            text(
                "SELECT user_id, COUNT(*) AS n "
                "FROM user_push_tokens "
                "WHERE is_active = true "
                "GROUP BY user_id ORDER BY user_id"
            )
        ).mappings():
            print(f"  user={row['user_id']:>3} active_tokens={row['n']}")

        print("\n=== Most recent fall_events ===")
        for row in conn.execute(
            text(
                "SELECT id, device_id, detected_at, confidence, sos_triggered, "
                "user_cancelled, survey_answers "
                "FROM fall_events ORDER BY id DESC LIMIT 5"
            )
        ).mappings():
            print(
                f"  fe={row['id']:>3} device={row['device_id']:<3} "
                f"conf={float(row['confidence']):.3f} "
                f"sos={row['sos_triggered']} dismissed={row['user_cancelled']} "
                f"survey={row['survey_answers']}"
            )

        print("\n=== Most recent sos_events ===")
        for row in conn.execute(
            text(
                "SELECT id, user_id, fall_event_id, trigger_type, status, "
                "triggered_at "
                "FROM sos_events ORDER BY id DESC LIMIT 5"
            )
        ).mappings():
            print(
                f"  sos={row['id']:>3} user={row['user_id']:<3} "
                f"fall={row['fall_event_id']} trigger={row['trigger_type']:<8} "
                f"status={row['status']:<10} at={row['triggered_at']}"
            )


if __name__ == "__main__":
    main()
