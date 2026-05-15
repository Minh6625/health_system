"""End-to-end smoke for the new fall confidence-threshold gate (P0 #1).

Workflow:
  1. POST /api/v1/mobile/telemetry/alert with event_type=fall_detected at high
     confidence (0.92) -> backend creates FallEvent + escalates to SOS.
  2. POST same endpoint with low confidence (0.40) -> backend creates
     FallEvent + soft Alert (alert_type=fall_detection, severity=high) but
     DOES NOT escalate to SOS.
  3. Verify by querying fall_events / alerts / sos_events tables.

Run with backend venv from `backend/`:
    $env:PYTHONPATH = (Get-Location).Path
    .\venv\Scripts\python.exe scripts\smoke_fall_threshold_e2e.py
"""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone

import httpx
from sqlalchemy import create_engine, text

from app.core.config import settings


PATIENT_USER_ID = 4
PATIENT_DEVICE_ID = 51
BACKEND_URL = os.getenv("BACKEND_URL_OVERRIDE", "http://127.0.0.1:8000")


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _post_fall(*, confidence: float, label: str) -> dict:
    payload = {
        "db_device_id": PATIENT_DEVICE_ID,
        "user_id": PATIENT_USER_ID,
        "event_type": "fall_detected",
        "severity": "critical",
        "timestamp": _now_iso(),
        "metadata": {
            "confidence": confidence,
            "variant": label,
            "source": "e2e_smoke",
        },
    }
    print(f"\n== POST /telemetry/alert (confidence={confidence}) ==")
    response = httpx.post(
        f"{BACKEND_URL}/api/v1/mobile/telemetry/alert", json=payload, timeout=15.0
    )
    print("status:", response.status_code)
    body = response.json()
    print("body:  ", body)
    return body


def _query_recent_fall_events(*, since_iso: str) -> list[dict]:
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT id, device_id, confidence::float AS confidence,
                       detected_at, features
                FROM fall_events
                WHERE device_id = :device_id
                  AND detected_at >= :since
                ORDER BY detected_at DESC
                """
            ),
            {"device_id": PATIENT_DEVICE_ID, "since": since_iso},
        ).mappings().all()
    return [dict(row) for row in rows]


def _query_recent_alerts(*, since_iso: str) -> list[dict]:
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT id, alert_type, severity, title, fall_event_id, data
                FROM alerts
                WHERE device_id = :device_id
                  AND created_at >= :since
                ORDER BY created_at DESC
                """
            ),
            {"device_id": PATIENT_DEVICE_ID, "since": since_iso},
        ).mappings().all()
    return [dict(row) for row in rows]


def _query_recent_sos(*, since_iso: str) -> list[dict]:
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT id, trigger_type, status, fall_event_id
                FROM sos_events
                WHERE user_id = :user_id
                  AND triggered_at >= :since
                ORDER BY triggered_at DESC
                """
            ),
            {"user_id": PATIENT_USER_ID, "since": since_iso},
        ).mappings().all()
    return [dict(row) for row in rows]


def main() -> None:
    cutoff = datetime.now(timezone.utc).replace(microsecond=0)

    # --- High-confidence fall: should escalate to SOS ---
    _post_fall(confidence=0.92, label="fall_high_confidence")
    time.sleep(1.0)

    # --- Low-confidence fall: should produce soft Alert, no SOS ---
    _post_fall(confidence=0.40, label="fall_low_confidence")
    time.sleep(1.0)

    print("\n== fall_events since cutoff ==")
    falls = _query_recent_fall_events(since_iso=cutoff.isoformat())
    for row in falls:
        print(
            f"  id={row['id']} confidence={row['confidence']:.2f} "
            f"variant={row['features'].get('variant') if isinstance(row.get('features'), dict) else '?'}"
        )
    assert len(falls) >= 2, "Expected at least 2 FallEvent rows"

    print("\n== alerts since cutoff ==")
    alerts = _query_recent_alerts(since_iso=cutoff.isoformat())
    for row in alerts:
        details = row.get("data")
        if isinstance(details, str):
            try:
                details = json.loads(details)
            except json.JSONDecodeError:
                details = {}
        sec = (details or {}).get("secondary_validation") if isinstance(details, dict) else None
        print(
            f"  id={row['id']} type={row['alert_type']} severity={row['severity']} "
            f"fall_event={row['fall_event_id']} secondary_validation={sec}"
        )

    print("\n== sos_events since cutoff ==")
    sos_rows = _query_recent_sos(since_iso=cutoff.isoformat())
    for row in sos_rows:
        print(
            f"  id={row['id']} trigger_type={row['trigger_type']} "
            f"status={row['status']} fall_event={row['fall_event_id']}"
        )

    # ---- Assertions on the gate behavior ----
    soft_alerts = [
        a for a in alerts
        if a["alert_type"] == "fall_detection"
        and a["severity"] == "high"
    ]
    assert any(
        isinstance(a.get("data"), dict)
        and a["data"].get("secondary_validation") == "pending_low_confidence"
        for a in soft_alerts
    ), "Expected at least one soft Alert with secondary_validation=pending_low_confidence"

    # High-confidence fall must produce a SOS event
    assert sos_rows, "Expected at least one SOS event for the high-confidence fall"
    high_fall_ids = {row["id"] for row in falls if abs(row["confidence"] - 0.92) < 0.05}
    sos_high_falls = [s for s in sos_rows if s["fall_event_id"] in high_fall_ids]
    assert sos_high_falls, "High-confidence FallEvent must be linked to a SOS event"

    # Low-confidence fall must NOT have a SOS event linked to it
    low_fall_ids = {row["id"] for row in falls if abs(row["confidence"] - 0.40) < 0.05}
    sos_low_falls = [s for s in sos_rows if s["fall_event_id"] in low_fall_ids]
    assert not sos_low_falls, (
        f"Low-confidence FallEvent {low_fall_ids} unexpectedly produced SOS: {sos_low_falls}"
    )

    print("\n== ALL ASSERTIONS PASSED ==")
    print("  - high-confidence (0.92) -> SOS escalated")
    print("  - low-confidence  (0.40) -> soft Alert with pending_low_confidence, NO SOS")


if __name__ == "__main__":
    main()
