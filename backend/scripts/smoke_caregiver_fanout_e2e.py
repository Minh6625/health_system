"""End-to-end smoke for caregiver fan-out on risk push (P1 #6).

Triggers /api/v1/mobile/telemetry/ingest with critical vitals, then verifies that the
new ``_resolve_risk_alert_recipients`` path created risk_critical Alert rows
for BOTH the patient and the caregiver who has ``can_receive_alerts=True``.

Run with backend venv from `backend/`:
    $env:PYTHONPATH = (Get-Location).Path
    .\venv\Scripts\python.exe scripts\smoke_caregiver_fanout_e2e.py
"""

from __future__ import annotations

import os
import time
from datetime import datetime, timezone

import httpx
from sqlalchemy import create_engine, text

from app.core.config import settings


PATIENT_USER_ID = 4
CAREGIVER_USER_ID = 5
PATIENT_DEVICE_ID = 51
BACKEND_URL = os.getenv("BACKEND_URL_OVERRIDE", "http://127.0.0.1:8000")


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _ingest_critical_vitals() -> None:
    payload = {
        "messages": [
            {
                "db_device_id": PATIENT_DEVICE_ID,
                "emitted_at": _now_iso(),
                "vitals": {
                    "heart_rate": 132,
                    "spo2": 89.5,
                    "temperature": 38.9,
                    "hrv": 18,
                    "respiratory_rate": 28,
                    "blood_pressure_sys": 165,
                    "blood_pressure_dia": 105,
                    "signal_quality": 0.97,
                    "motion_artifact": False,
                },
            }
        ]
    }
    print("== ingest critical vitals ==")
    response = httpx.post(
        f"{BACKEND_URL}/api/v1/mobile/telemetry/ingest", json=payload, timeout=15.0
    )
    print("status:", response.status_code)
    print("body:  ", response.json())


def _query_recent_risk_alerts(*, since_iso: str) -> list[dict]:
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT id, user_id, device_id, alert_type, severity, title, data
                FROM alerts
                WHERE device_id = :device_id
                  AND alert_type IN ('risk_high', 'risk_critical')
                  AND created_at >= :since
                ORDER BY created_at DESC
                """
            ),
            {"device_id": PATIENT_DEVICE_ID, "since": since_iso},
        ).mappings().all()
    return [dict(row) for row in rows]


def main() -> None:
    cutoff = datetime.now(timezone.utc).replace(microsecond=0)
    _ingest_critical_vitals()
    time.sleep(2.0)

    alerts = _query_recent_risk_alerts(since_iso=cutoff.isoformat())
    print("\n== risk alerts since cutoff ==")
    for row in alerts:
        print(
            f"  id={row['id']} user={row['user_id']} type={row['alert_type']} "
            f"severity={row['severity']}"
        )

    recipient_ids = sorted({row["user_id"] for row in alerts})
    print(f"\nrecipients = {recipient_ids}")
    assert PATIENT_USER_ID in recipient_ids, (
        f"Patient user {PATIENT_USER_ID} missing from risk alert recipients"
    )
    assert CAREGIVER_USER_ID in recipient_ids, (
        f"Caregiver user {CAREGIVER_USER_ID} missing from risk alert recipients"
        " (P1 #6 fan-out is broken)"
    )
    print("\n== ALL ASSERTIONS PASSED ==")
    print("  - patient (id=4) received risk alert")
    print("  - caregiver (id=5) received risk alert via P1 #6 fan-out")


if __name__ == "__main__":
    main()
