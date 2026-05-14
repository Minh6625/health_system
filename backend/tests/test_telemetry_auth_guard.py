"""Regression test for HS-004 — telemetry endpoints require internal service auth.

Verifies /sleep, /imu-window, /sleep-risk reject requests without X-Internal-Service header.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    """TestClient with internal secret configured so guard is active."""
    with patch(
        "app.core.dependencies._INTERNAL_SERVICE_SECRET",
        "test-internal-secret",
    ):
        from app.main import app

        yield TestClient(app)


@pytest.fixture
def authed_headers():
    return {
        "X-Internal-Service": "iot-simulator",
        "X-Internal-Secret": "test-internal-secret",
    }


class TestSleepEndpointAuth:
    def test_sleep_rejects_no_header(self, client):
        resp = client.post(
            "/mobile/telemetry/sleep",
            json={"db_device_id": 1, "user_id": 1, "date": "2026-05-14"},
        )
        # Should be 401 or 403 (depends on require_internal_service impl)
        assert resp.status_code in (401, 403)

    def test_sleep_rejects_wrong_header(self, client):
        resp = client.post(
            "/mobile/telemetry/sleep",
            json={"db_device_id": 1, "user_id": 1, "date": "2026-05-14"},
            headers={"X-Internal-Service": "wrong-service"},
        )
        assert resp.status_code in (401, 403)


class TestImuWindowEndpointAuth:
    def test_imu_window_rejects_no_header(self, client):
        resp = client.post(
            "/mobile/telemetry/imu-window",
            json={"device_id": "dev1", "data": []},
        )
        assert resp.status_code in (401, 403)


class TestSleepRiskEndpointAuth:
    def test_sleep_risk_rejects_no_header(self, client):
        resp = client.post(
            "/mobile/telemetry/sleep-risk",
            json={"device_id": "dev1", "records": []},
        )
        assert resp.status_code in (401, 403)
