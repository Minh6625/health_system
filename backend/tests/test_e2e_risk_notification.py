r"""
E2E tests for the risk notification pipeline (Threshold 2).

Verifies the full flow:
  POST /mobile/risk/calculate  ->  RiskScore saved  ->  Alert rows created

Prerequisites:
  - Live Postgres with health_system schema (users, devices, vitals, alerts, risk_scores)
  - At least one active device bound to a user with recent vitals

Run with:
    $env:RUN_REAL_DB_E2E = "1"
    .\venv\Scripts\python.exe -m pytest tests/test_e2e_risk_notification.py -q -s
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Iterator

import httpx
import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from app.core.config import settings


# ---------------------------------------------------------------------------
# Gate: only run when RUN_REAL_DB_E2E=1
# ---------------------------------------------------------------------------

RUN_REAL_DB_E2E = os.getenv("RUN_REAL_DB_E2E") == "1"
BACKEND_DIR = Path(__file__).resolve().parents[1]
VENV_PYTHON = BACKEND_DIR / "venv" / "Scripts" / "python.exe"

pytestmark = pytest.mark.skipif(
    not RUN_REAL_DB_E2E,
    reason="Set RUN_REAL_DB_E2E=1 to run live backend/live DB E2E tests.",
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _python_executable() -> str:
    if VENV_PYTHON.exists():
        return str(VENV_PYTHON)
    return sys.executable


def _pick_free_port() -> int:
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def engine() -> Iterator[Engine]:
    db_engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    try:
        yield db_engine
    finally:
        db_engine.dispose()


@pytest.fixture(scope="session")
def backend_base_url() -> Iterator[str]:
    """Spin up uvicorn on a random port and yield the base URL."""
    port = _pick_free_port()
    env = os.environ.copy()
    existing_pythonpath = env.get("PYTHONPATH")
    env["PYTHONPATH"] = (
        str(BACKEND_DIR)
        if not existing_pythonpath
        else f"{BACKEND_DIR}{os.pathsep}{existing_pythonpath}"
    )
    # Disable risk-calc cooldown for testing
    env["RISK_ALERT_COOLDOWN_SECONDS"] = "0"
    env["RISK_COOLDOWN_SECONDS"] = "0"
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
        stderr=subprocess.PIPE,
    )

    base_url = f"http://127.0.0.1:{port}"

    # Wait for the server to be ready
    for _ in range(40):
        try:
            resp = httpx.get(f"{base_url}/mobile/health", timeout=1.0)
            if resp.status_code == 200:
                break
        except (httpx.ConnectError, httpx.ReadTimeout, httpx.ConnectTimeout):
            pass
        time.sleep(0.5)
    else:
        process.terminate()
        raise RuntimeError("Backend did not become ready in time")

    yield base_url

    process.terminate()
    process.wait(timeout=5)


@pytest.fixture(scope="session")
def test_device_info(engine: Engine) -> dict:
    """Find an active device with a bound user and recent vitals."""
    with engine.connect() as conn:
        row = conn.execute(
            text("""
                SELECT d.id AS device_id, d.user_id
                FROM devices d
                WHERE d.is_active = true
                  AND d.deleted_at IS NULL
                  AND d.user_id IS NOT NULL
                ORDER BY d.id
                LIMIT 1
            """)
        ).mappings().first()

        if row is None:
            pytest.skip("No active device with user found in DB")

        device_id = int(row["device_id"])
        user_id = int(row["user_id"])

        # Check that vitals exist for this device
        vitals_count = conn.execute(
            text("SELECT count(*) FROM vitals WHERE device_id = :did"),
            {"did": device_id},
        ).scalar()

        if not vitals_count:
            pytest.skip(f"Device {device_id} has no vitals data")

        return {"device_id": device_id, "user_id": user_id}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestRiskNotificationE2E:
    """E2E tests for risk calculation -> alert creation pipeline."""

    def test_calculate_risk_returns_score(
        self,
        backend_base_url: str,
        test_device_info: dict,
    ) -> None:
        """POST /mobile/risk/calculate returns a valid risk score response."""
        resp = httpx.post(
            f"{backend_base_url}/mobile/risk/calculate",
            json={"device_id": test_device_info["device_id"]},
            headers={"X-Internal-Service": "iot-simulator"},
            timeout=15.0,
        )
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"

        body = resp.json()
        assert "risk_score_id" in body
        assert "score" in body
        assert "risk_level" in body
        assert body["risk_level"] in ("low", "medium", "critical")

    def test_risk_score_persisted_in_db(
        self,
        backend_base_url: str,
        test_device_info: dict,
        engine: Engine,
    ) -> None:
        """After /mobile/risk/calculate, the risk_scores table has a new row."""
        # Record count before
        with engine.connect() as conn:
            before_count = conn.execute(
                text(
                    "SELECT count(*) FROM risk_scores WHERE device_id = :did"
                ),
                {"did": test_device_info["device_id"]},
            ).scalar()

        # Trigger risk calculation
        resp = httpx.post(
            f"{backend_base_url}/mobile/risk/calculate",
            json={"device_id": test_device_info["device_id"]},
            headers={"X-Internal-Service": "iot-simulator"},
            timeout=15.0,
        )
        assert resp.status_code == 200

        # Verify new row in DB
        with engine.connect() as conn:
            after_count = conn.execute(
                text(
                    "SELECT count(*) FROM risk_scores WHERE device_id = :did"
                ),
                {"did": test_device_info["device_id"]},
            ).scalar()

        assert after_count > before_count, (
            f"Expected new risk_score row: before={before_count}, after={after_count}"
        )

    def test_alert_created_for_non_low_risk(
        self,
        backend_base_url: str,
        test_device_info: dict,
        engine: Engine,
    ) -> None:
        """When risk_level is medium or critical, an Alert row is created.

        If the model returns 'low', no alert is expected — the test
        verifies the response and skips the alert assertion.
        """
        device_id = test_device_info["device_id"]

        # Clean up any old test alerts for this device to avoid false positives
        with engine.connect() as conn:
            old_alert_count = conn.execute(
                text(
                    "SELECT count(*) FROM alerts "
                    "WHERE device_id = :did "
                    "AND alert_type IN ('risk_high', 'risk_critical')"
                ),
                {"did": device_id},
            ).scalar()

        # Trigger risk calculation
        resp = httpx.post(
            f"{backend_base_url}/mobile/risk/calculate",
            json={"device_id": device_id},
            headers={"X-Internal-Service": "iot-simulator"},
            timeout=15.0,
        )
        assert resp.status_code == 200
        body = resp.json()
        risk_level = body["risk_level"]

        if risk_level == "low":
            # No alert expected for low risk — verify no new alerts
            with engine.connect() as conn:
                new_alert_count = conn.execute(
                    text(
                        "SELECT count(*) FROM alerts "
                        "WHERE device_id = :did "
                        "AND alert_type IN ('risk_high', 'risk_critical')"
                    ),
                    {"did": device_id},
                ).scalar()
            assert new_alert_count == old_alert_count, (
                "No new alert expected for low risk, but count changed"
            )
            pytest.skip("Risk level is 'low' — no alert to verify")
            return

        # For medium / critical, verify alert was created
        expected_alert_type = (
            "risk_critical" if risk_level == "critical" else "risk_high"
        )

        # Small delay to allow post-commit dispatch
        time.sleep(0.5)

        with engine.connect() as conn:
            new_alert_count = conn.execute(
                text(
                    "SELECT count(*) FROM alerts "
                    "WHERE device_id = :did "
                    "AND alert_type = :atype"
                ),
                {"did": device_id, "atype": expected_alert_type},
            ).scalar()
            alert_row = conn.execute(
                text(
                    "SELECT id, alert_type, severity, title, device_id, user_id "
                    "FROM alerts "
                    "WHERE device_id = :did "
                    "AND alert_type = :atype "
                    "ORDER BY created_at DESC "
                    "LIMIT 1"
                ),
                {"did": device_id, "atype": expected_alert_type},
            ).mappings().first()

        assert alert_row is not None, (
            f"Expected alert of type '{expected_alert_type}' for device {device_id}"
        )
        assert new_alert_count == old_alert_count + 1, (
            "Expected exactly one new initial alert for the patient"
        )
        assert alert_row["device_id"] == device_id
        assert alert_row["user_id"] == test_device_info["user_id"]
        assert alert_row["severity"] in ("high", "critical")

    def test_cooldown_prevents_duplicate_alerts(
        self,
        backend_base_url: str,
        test_device_info: dict,
        engine: Engine,
    ) -> None:
        """Two rapid calls should not create duplicate alerts (cooldown)."""
        device_id = test_device_info["device_id"]

        # First call
        resp1 = httpx.post(
            f"{backend_base_url}/mobile/risk/calculate",
            json={"device_id": device_id},
            headers={"X-Internal-Service": "iot-simulator"},
            timeout=15.0,
        )
        assert resp1.status_code == 200
        body1 = resp1.json()

        if body1["risk_level"] == "low":
            pytest.skip("Risk level is 'low' — cooldown test not applicable")
            return

        expected_alert_type = (
            "risk_critical" if body1["risk_level"] == "critical" else "risk_high"
        )

        time.sleep(0.5)

        # Count alerts after first call
        with engine.connect() as conn:
            count_after_first = conn.execute(
                text(
                    "SELECT count(*) FROM alerts "
                    "WHERE device_id = :did "
                    "AND alert_type = :atype"
                ),
                {"did": device_id, "atype": expected_alert_type},
            ).scalar()

        # Second call immediately (should hit cooldown for ALERT, not for risk calc)
        resp2 = httpx.post(
            f"{backend_base_url}/mobile/risk/calculate",
            json={"device_id": device_id},
            headers={"X-Internal-Service": "iot-simulator"},
            timeout=15.0,
        )
        assert resp2.status_code == 200

        time.sleep(0.5)

        # Count should not increase (cooldown prevents duplicate alert)
        with engine.connect() as conn:
            count_after_second = conn.execute(
                text(
                    "SELECT count(*) FROM alerts "
                    "WHERE device_id = :did "
                    "AND alert_type = :atype"
                ),
                {"did": device_id, "atype": expected_alert_type},
            ).scalar()

        assert count_after_second == count_after_first, (
            f"Cooldown should prevent duplicate alerts: "
            f"after_first={count_after_first}, after_second={count_after_second}"
        )

    def test_internal_service_header_required(
        self,
        backend_base_url: str,
        test_device_info: dict,
    ) -> None:
        """Without auth or X-Internal-Service header, the request is rejected."""
        resp = httpx.post(
            f"{backend_base_url}/mobile/risk/calculate",
            json={"device_id": test_device_info["device_id"]},
            timeout=10.0,
        )
        # Should be 401 or 403 (not authenticated)
        assert resp.status_code in (401, 403), (
            f"Expected 401/403 without auth, got {resp.status_code}"
        )
