r"""
Real E2E tests for telemetry ingestion against a live backend and live Postgres.

Run with:
    $env:RUN_REAL_DB_E2E = "1"
    .\venv\Scripts\python.exe -m pytest tests/test_e2e_telemetry_real_db.py -q -s
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
import uuid
from contextlib import closing
from datetime import UTC, date, datetime, timedelta
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


def _iso_utc(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _auth_headers(*, user_id: int, target_profile_id: int | None = None) -> dict[str, str]:
    token = create_access_token({"user_id": user_id})
    headers = {"Authorization": f"Bearer {token}"}
    if target_profile_id is not None:
        headers["X-Target-Profile-Id"] = str(target_profile_id)
    return headers


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
                    startup_error = (process.stdout.read() if process.stdout else "").strip()
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
            "Backend failed to start for real DB E2E test."
            + (f" Output: {startup_error}" if startup_error else "")
        )
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


@pytest.fixture(scope="session")
def temp_device(engine: Engine) -> Iterator[dict[str, int]]:
    with engine.begin() as connection:
        user_id = connection.execute(
            text(
                """
                SELECT id
                FROM users
                WHERE deleted_at IS NULL
                ORDER BY id
                LIMIT 1
                """
            )
        ).scalar()

        if user_id is None:
            pytest.skip("No user row available to create an E2E telemetry device.")

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
                "user_id": int(user_id),
                "device_name": f"E2E Telemetry Device {uuid.uuid4().hex[:8]}",
                "serial_number": f"e2e-{uuid.uuid4()}",
            },
        ).scalar_one()

    try:
        yield {"user_id": int(user_id), "device_id": int(device_id)}
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM vitals WHERE device_id = :device_id"),
                {"device_id": int(device_id)},
            )
            connection.execute(
                text("DELETE FROM sleep_sessions WHERE device_id = :device_id"),
                {"device_id": int(device_id)},
            )
            connection.execute(
                text("DELETE FROM devices WHERE id = :device_id"),
                {"device_id": int(device_id)},
            )


@pytest.fixture(scope="session")
def temp_caregiver(engine: Engine) -> Iterator[dict[str, int]]:
    caregiver_email = f"sleep-e2e-caregiver-{uuid.uuid4().hex[:12]}@example.com"

    with engine.begin() as connection:
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
                    'caregiver',
                    TRUE,
                    TRUE
                )
                RETURNING id
                """
            ),
            {
                "email": caregiver_email,
                "password_hash": "e2e-not-used",
                "full_name": "Sleep E2E Caregiver",
            },
        ).scalar_one()

    try:
        yield {"user_id": int(caregiver_id)}
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM user_relationships WHERE caregiver_id = :caregiver_id"),
                {"caregiver_id": int(caregiver_id)},
            )
            connection.execute(
                text("DELETE FROM users WHERE id = :caregiver_id"),
                {"caregiver_id": int(caregiver_id)},
            )


@pytest.fixture(autouse=True)
def clean_device_rows(engine: Engine, temp_device: dict[str, int]) -> Iterator[None]:
    with engine.begin() as connection:
        connection.execute(
            text("DELETE FROM vitals WHERE device_id = :device_id"),
            {"device_id": temp_device["device_id"]},
        )
        connection.execute(
            text("DELETE FROM sleep_sessions WHERE device_id = :device_id"),
            {"device_id": temp_device["device_id"]},
        )
    yield
    with engine.begin() as connection:
        connection.execute(
            text("DELETE FROM vitals WHERE device_id = :device_id"),
            {"device_id": temp_device["device_id"]},
        )
        connection.execute(
            text("DELETE FROM sleep_sessions WHERE device_id = :device_id"),
            {"device_id": temp_device["device_id"]},
        )


def _seed_sleep_session(
    *,
    backend_base_url: str,
    temp_device: dict[str, int],
    sleep_date: date,
) -> httpx.Response:
    start_time = datetime.now(UTC).replace(microsecond=0) - timedelta(hours=7)
    end_time = start_time + timedelta(hours=6, minutes=35)
    payload = {
        "db_device_id": temp_device["device_id"],
        "user_id": temp_device["user_id"],
        "date": sleep_date.isoformat(),
        "score": 86,
        "efficiency": 92.4,
        "duration_minutes": 395,
        "phases": {
            "deep": 90,
            "light": 205,
            "rem": 70,
            "awake": 30,
        },
        "start_time": _iso_utc(start_time),
        "end_time": _iso_utc(end_time),
    }

    with httpx.Client(timeout=10.0) as client:
        return client.post(f"{backend_base_url}/mobile/telemetry/sleep", json=payload)


def test_vital_ingest_persists_to_postgres(
    backend_base_url: str,
    engine: Engine,
    temp_device: dict[str, int],
) -> None:
    emitted_at = datetime.now(UTC).replace(microsecond=0)

    payload = {
        "messages": [
            {
                "db_device_id": temp_device["device_id"],
                "emitted_at": _iso_utc(emitted_at),
                "vitals": {
                    "heart_rate": 78,
                    "spo2": 97,
                    "temperature": 36.6,
                    "hrv": 52,
                    "respiratory_rate": 17,
                    "blood_pressure_sys": 118,
                    "blood_pressure_dia": 76,
                    "signal_quality": 1,
                    "motion_artifact": False,
                },
            }
        ]
    }

    with httpx.Client(timeout=10.0) as client:
        response = client.post(f"{backend_base_url}/mobile/telemetry/ingest", json=payload)

    assert response.status_code == 200, response.text
    assert response.json() == {"ingested": 1, "errors": []}

    with engine.begin() as connection:
        vital_row = connection.execute(
            text(
                """
                SELECT
                    device_id,
                    heart_rate,
                    spo2,
                    temperature,
                    respiratory_rate,
                    blood_pressure_sys,
                    blood_pressure_dia,
                    signal_quality,
                    motion_artifact
                FROM vitals
                WHERE device_id = :device_id
                  AND time = :emitted_at
                """
            ),
            {
                "device_id": temp_device["device_id"],
                "emitted_at": emitted_at,
            },
        ).mappings().one()

        sync_row = connection.execute(
            text(
                """
                SELECT last_sync_at
                FROM devices
                WHERE id = :device_id
                """
            ),
            {"device_id": temp_device["device_id"]},
        ).mappings().one()

    assert vital_row["device_id"] == temp_device["device_id"]
    assert float(vital_row["heart_rate"]) == pytest.approx(78.0)
    assert float(vital_row["spo2"]) == pytest.approx(97.0)
    assert float(vital_row["temperature"]) == pytest.approx(36.6)
    assert float(vital_row["respiratory_rate"]) == pytest.approx(17.0)
    assert int(vital_row["blood_pressure_sys"]) == 118
    assert int(vital_row["blood_pressure_dia"]) == 76
    assert int(vital_row["signal_quality"]) == 1
    assert vital_row["motion_artifact"] is False
    assert sync_row["last_sync_at"] is not None


def test_sleep_ingest_persists_to_postgres(
    backend_base_url: str,
    engine: Engine,
    temp_device: dict[str, int],
) -> None:
    sleep_date = date.today() + timedelta(days=1)
    response = _seed_sleep_session(
        backend_base_url=backend_base_url,
        temp_device=temp_device,
        sleep_date=sleep_date,
    )

    assert response.status_code == 200, response.text
    assert response.json() == {"ingested": 1, "errors": []}

    with engine.begin() as connection:
        sleep_row = connection.execute(
            text(
                """
                SELECT
                    user_id,
                    device_id,
                    sleep_score,
                    phases,
                    wake_count,
                    sleep_date
                FROM sleep_sessions
                WHERE user_id = :user_id
                  AND device_id = :device_id
                  AND sleep_date = :sleep_date
                """
            ),
            {
                "user_id": temp_device["user_id"],
                "device_id": temp_device["device_id"],
                "sleep_date": sleep_date,
            },
        ).mappings().one()

    assert sleep_row["user_id"] == temp_device["user_id"]
    assert sleep_row["device_id"] == temp_device["device_id"]
    assert int(sleep_row["sleep_score"]) == 86
    assert int(sleep_row["wake_count"]) == 1
    assert sleep_row["sleep_date"] == sleep_date
    assert sleep_row["phases"] == {
        "deep": 90,
        "light": 205,
        "rem": 70,
        "awake": 30,
    }


def test_sleep_metrics_latest_and_history_require_auth_and_return_canonical_fields(
    backend_base_url: str,
    temp_device: dict[str, int],
) -> None:
    today = date.today() + timedelta(days=1)
    ingest_response = _seed_sleep_session(
        backend_base_url=backend_base_url,
        temp_device=temp_device,
        sleep_date=today,
    )
    assert ingest_response.status_code == 200, ingest_response.text

    headers = _auth_headers(user_id=temp_device["user_id"])
    with httpx.Client(timeout=10.0, headers=headers) as client:
        latest_response = client.get(f"{backend_base_url}/mobile/metrics/sleep/latest")
        history_response = client.get(
            f"{backend_base_url}/mobile/metrics/sleep/history",
            params={"from_date": today.isoformat(), "to_date": today.isoformat()},
        )

    assert latest_response.status_code == 200, latest_response.text
    assert history_response.status_code == 200, history_response.text

    latest_payload = latest_response.json()
    history_payload = history_response.json()
    assert latest_payload["sleep_date"] == today.isoformat()
    assert latest_payload["quality_score"] == 86
    assert latest_payload["quality_label"] == "GOOD"
    assert latest_payload["sleep_minutes"] == 365
    assert latest_payload["awake_minutes"] == 30
    assert latest_payload["wake_count"] == 1
    assert latest_payload["phases"] == {
        "awake": 30,
        "light": 205,
        "deep": 90,
        "rem": 70,
    }
    assert history_payload["data"] == [latest_payload]


def test_sleep_metrics_linked_profile_requires_relationship(
    backend_base_url: str,
    engine: Engine,
    temp_device: dict[str, int],
    temp_caregiver: dict[str, int],
) -> None:
    today = date.today() + timedelta(days=1)
    ingest_response = _seed_sleep_session(
        backend_base_url=backend_base_url,
        temp_device=temp_device,
        sleep_date=today,
    )
    assert ingest_response.status_code == 200, ingest_response.text

    headers = _auth_headers(
        user_id=temp_caregiver["user_id"],
        target_profile_id=temp_device["user_id"],
    )
    with httpx.Client(timeout=10.0, headers=headers) as client:
        forbidden_response = client.get(f"{backend_base_url}/mobile/metrics/sleep/latest")

    assert forbidden_response.status_code == 403, forbidden_response.text

    with engine.begin() as connection:
        connection.execute(
            text(
                """
                INSERT INTO user_relationships (
                    patient_id,
                    caregiver_id,
                    relationship_type,
                    status,
                    can_view_vitals,
                    can_receive_alerts,
                    can_view_location
                )
                VALUES (
                    :patient_id,
                    :caregiver_id,
                    'family',
                    'accepted',
                    TRUE,
                    FALSE,
                    FALSE
                )
                """
            ),
            {
                "patient_id": temp_device["user_id"],
                "caregiver_id": temp_caregiver["user_id"],
            },
        )

    with httpx.Client(timeout=10.0, headers=headers) as client:
        latest_response = client.get(f"{backend_base_url}/mobile/metrics/sleep/latest")
        history_response = client.get(
            f"{backend_base_url}/mobile/metrics/sleep/history",
            params={"from_date": today.isoformat(), "to_date": today.isoformat()},
        )

    assert latest_response.status_code == 200, latest_response.text
    assert history_response.status_code == 200, history_response.text
    assert latest_response.json()["sleep_date"] == today.isoformat()
    assert history_response.json()["data"][0]["sleep_date"] == today.isoformat()
