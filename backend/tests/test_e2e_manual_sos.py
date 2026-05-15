r"""
Real DB E2E tests for the manual SOS caregiver round-trip.

Run with:
    $env:RUN_REAL_DB_E2E = "1"
    .\venv\Scripts\python.exe -m pytest tests/test_e2e_manual_sos.py -q -s
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
import uuid
from contextlib import closing
from pathlib import Path
from typing import Iterator

import httpx
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from app.core.config import settings
from app.utils.jwt import create_access_token


RUN_REAL_DB_E2E = os.getenv("RUN_REAL_DB_E2E") == "1"
BACKEND_DIR = Path(__file__).resolve().parents[1]
VENV_PYTHON = BACKEND_DIR / "venv" / "Scripts" / "python.exe"

pytestmark = pytest.mark.skipif(
    not RUN_REAL_DB_E2E,
    reason="Set RUN_REAL_DB_E2E=1 to run live backend/live DB E2E tests.",
)


def _python_executable() -> str:
    if VENV_PYTHON.exists():
        return str(VENV_PYTHON)
    return sys.executable


def _pick_free_port() -> int:
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _auth_headers(*, user_id: int) -> dict[str, str]:
    token = create_access_token({"user_id": user_id})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture(scope="session")
def engine() -> Iterator[Engine]:
    db_engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    try:
        yield db_engine
    finally:
        db_engine.dispose()


@pytest.fixture(scope="session")
def backend_base_url() -> Iterator[str]:
    port = _pick_free_port()
    env = os.environ.copy()
    existing_pythonpath = env.get("PYTHONPATH")
    env["PYTHONPATH"] = (
        str(BACKEND_DIR)
        if not existing_pythonpath
        else f"{BACKEND_DIR}{os.pathsep}{existing_pythonpath}"
    )
    env["E2E_DISABLE_PUSH"] = "1"

    process = subprocess.Popen(
        [
            _python_executable(),
            "-m",
            "uvicorn",
            "app.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
        ],
        cwd=str(BACKEND_DIR),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    base_url = f"http://127.0.0.1:{port}"
    startup_error = ""

    try:
        with httpx.Client(timeout=2.0) as client:
            for _ in range(40):
                if process.poll() is not None:
                    startup_error = (
                        process.stdout.read() if process.stdout else ""
                    ).strip()
                    break
                try:
                    response = client.get(f"{base_url}/mobile-docs")
                    if response.status_code == 200:
                        yield base_url
                        return
                except httpx.HTTPError:
                    pass
                time.sleep(0.25)
        raise RuntimeError(
            "Backend failed to start for manual SOS E2E test."
            + (f" Output: {startup_error}" if startup_error else "")
        )
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


@pytest.fixture()
def emergency_users(engine: Engine) -> Iterator[dict[str, int]]:
    patient_email = f"manual-sos-patient-{uuid.uuid4().hex[:12]}@example.com"
    caregiver_email = f"manual-sos-caregiver-{uuid.uuid4().hex[:12]}@example.com"
    device_id: int | None = None

    with engine.begin() as connection:
        patient_id = connection.execute(
            text(
                """
                INSERT INTO users (
                    email,
                    password_hash,
                    full_name,
                    role,
                    is_active,
                    is_verified
                )
                VALUES (
                    :email,
                    :password_hash,
                    :full_name,
                    'user',
                    TRUE,
                    TRUE
                )
                RETURNING id
                """
            ),
            {
                "email": patient_email,
                "password_hash": "e2e-not-used",
                "full_name": "Emergency Manual SOS Patient",
            },
        ).scalar_one()

        caregiver_id = connection.execute(
            text(
                """
                INSERT INTO users (
                    email,
                    password_hash,
                    full_name,
                    role,
                    is_active,
                    is_verified
                )
                VALUES (
                    :email,
                    :password_hash,
                    :full_name,
                    'user',
                    TRUE,
                    TRUE
                )
                RETURNING id
                """
            ),
            {
                "email": caregiver_email,
                "password_hash": "e2e-not-used",
                "full_name": "Emergency Manual SOS Caregiver",
            },
        ).scalar_one()

        connection.execute(
            text(
                """
                INSERT INTO user_relationships (
                    patient_id,
                    caregiver_id,
                    relationship_type,
                    is_primary,
                    status,
                    can_view_vitals,
                    can_receive_alerts,
                    can_view_location
                )
                VALUES (
                    :patient_id,
                    :caregiver_id,
                    'family',
                    TRUE,
                    'accepted',
                    TRUE,
                    TRUE,
                    TRUE
                )
                """
            ),
            {
                "patient_id": int(patient_id),
                "caregiver_id": int(caregiver_id),
            },
        )

        device_id = connection.execute(
            text(
                """
                INSERT INTO devices (
                    user_id,
                    device_name,
                    device_type,
                    serial_number,
                    is_active
                )
                VALUES (
                    :user_id,
                    :device_name,
                    'smartwatch',
                    :serial_number,
                    TRUE
                )
                RETURNING id
                """
            ),
            {
                "user_id": int(patient_id),
                "device_name": f"Emergency E2E Device {uuid.uuid4().hex[:8]}",
                "serial_number": f"emergency-e2e-{uuid.uuid4()}",
            },
        ).scalar_one()

    try:
        yield {
            "patient_id": int(patient_id),
            "caregiver_id": int(caregiver_id),
            "device_id": int(device_id),
        }
    finally:
        with engine.begin() as connection:
            connection.execute(
                text(
                    """
                    DELETE FROM alerts
                    WHERE user_id IN (:patient_id, :caregiver_id)
                    """
                ),
                {
                    "patient_id": int(patient_id),
                    "caregiver_id": int(caregiver_id),
                },
            )
            if device_id is not None:
                connection.execute(
                    text(
                        """
                        DELETE FROM devices
                        WHERE id = :device_id
                        """
                    ),
                    {"device_id": int(device_id)},
                )
            connection.execute(
                text(
                    """
                    DELETE FROM sos_events
                    WHERE user_id = :patient_id
                    """
                ),
                {"patient_id": int(patient_id)},
            )
            connection.execute(
                text(
                    """
                    DELETE FROM user_relationships
                    WHERE patient_id = :patient_id
                      AND caregiver_id = :caregiver_id
                    """
                ),
                {
                    "patient_id": int(patient_id),
                    "caregiver_id": int(caregiver_id),
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM users
                    WHERE id IN (:patient_id, :caregiver_id)
                    """
                ),
                {
                    "patient_id": int(patient_id),
                    "caregiver_id": int(caregiver_id),
                },
            )


def test_manual_sos_round_trip_persists_lists_details_and_resolves(
    backend_base_url: str,
    engine: Engine,
    emergency_users: dict[str, int],
) -> None:
    patient_id = emergency_users["patient_id"]
    caregiver_id = emergency_users["caregiver_id"]

    with httpx.Client(base_url=backend_base_url, timeout=20.0) as client:
        unauthorized = client.post(
            "/api/v1/mobile/emergency/sos/trigger",
            json={"trigger_type": "manual"},
        )
        assert unauthorized.status_code in {401, 403}

        trigger_response = client.post(
            "/api/v1/mobile/emergency/sos/trigger",
            headers=_auth_headers(user_id=patient_id),
            json={
                "trigger_type": "manual",
                "address": "Manual SOS E2E route verification",
                "latitude": 10.1234,
                "longitude": 106.5678,
            },
        )
        assert trigger_response.status_code == 200, trigger_response.text

        trigger_body = trigger_response.json()
        assert trigger_body["success"] is True
        assert trigger_body["recipient_count"] == 1
        sos_id = int(trigger_body["sos_id"])

        with engine.begin() as connection:
            sos_row = connection.execute(
                text(
                    """
                    SELECT id, user_id, trigger_type, status, address
                    FROM sos_events
                    WHERE id = :sos_id
                    """
                ),
                {"sos_id": sos_id},
            ).mappings().one()
            assert int(sos_row["user_id"]) == patient_id
            assert sos_row["trigger_type"] == "manual"
            assert sos_row["status"] == "active"
            assert sos_row["address"] == "Manual SOS E2E route verification"

            caregiver_alert = connection.execute(
                text(
                    """
                    SELECT id, user_id, alert_type, title, data ->> 'sos_id' AS linked_sos_id
                    FROM alerts
                    WHERE user_id = :caregiver_id
                      AND alert_type = 'sos'
                      AND data ->> 'sos_id' = :linked_sos_id
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "linked_sos_id": str(sos_id),
                },
            ).mappings().one()
            assert int(caregiver_alert["user_id"]) == caregiver_id
            assert caregiver_alert["alert_type"] == "sos"
            assert "SOS" in caregiver_alert["title"]

        list_response = client.get(
            "/api/v1/mobile/emergency/caregiver/sos-alerts",
            headers=_auth_headers(user_id=caregiver_id),
            params={"status": "active"},
        )
        assert list_response.status_code == 200, list_response.text
        list_body = list_response.json()
        matched_list_item = next(
            item for item in list_body["sos_alerts"] if int(item["sos_id"]) == sos_id
        )
        assert matched_list_item["trigger_type"] == "manual"
        assert matched_list_item["status"] == "active"

        detail_response = client.get(
            f"/api/v1/mobile/emergency/sos/{sos_id}",
            headers=_auth_headers(user_id=caregiver_id),
        )
        assert detail_response.status_code == 200, detail_response.text
        detail_body = detail_response.json()
        assert detail_body["trigger_type"] == "manual"
        assert detail_body["status"] == "active"

        resolve_response = client.post(
            f"/api/v1/mobile/emergency/sos/{sos_id}/resolve",
            headers=_auth_headers(user_id=caregiver_id),
            json={
                "resolution_status": "safe",
                "notes": "Manual SOS E2E resolved",
            },
        )
        assert resolve_response.status_code == 200, resolve_response.text
        assert resolve_response.json()["success"] is True

        resolved_detail = client.get(
            f"/api/v1/mobile/emergency/sos/{sos_id}",
            headers=_auth_headers(user_id=caregiver_id),
        )
        assert resolved_detail.status_code == 200, resolved_detail.text
        resolved_body = resolved_detail.json()
        assert resolved_body["status"] == "resolved"
        assert resolved_body["resolution"]["resolution_status"] == "safe"
        assert resolved_body["resolution"]["notes"] == "Manual SOS E2E resolved"

        resolved_list = client.get(
            "/api/v1/mobile/emergency/caregiver/sos-alerts",
            headers=_auth_headers(user_id=caregiver_id),
            params={"status": "resolved"},
        )
        assert resolved_list.status_code == 200, resolved_list.text
        assert any(
            int(item["sos_id"]) == sos_id
            and item["status"] == "resolved"
            for item in resolved_list.json()["sos_alerts"]
        )
