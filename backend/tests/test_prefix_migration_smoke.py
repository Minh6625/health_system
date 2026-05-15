"""Smoke test for ADR-021 endpoint prefix migration.

Verifies that after dropping root_path magic and explicitly mounting the
mobile API router at /api/v1/mobile, both the canonical and legacy paths
behave correctly:

- /api/v1/mobile/health -> 200 (canonical)
- /mobile/health -> 404 (legacy path no longer served)

Related: XR-001 (topology drift), Phase 7 slice S1.
"""

from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    with patch(
        "app.core.config.settings.INTERNAL_SERVICE_SECRET",
        "test-internal-secret",
    ):
        from app.main import app

        yield TestClient(app)


class TestCanonicalPrefix:
    """ADR-021: canonical mobile API surface is /api/v1/mobile/*."""

    def test_canonical_health_returns_200(self, client):
        resp = client.get("/api/v1/mobile/health")
        assert resp.status_code == 200, resp.text

    def test_canonical_health_body_has_expected_shape(self, client):
        resp = client.get("/api/v1/mobile/health")
        assert resp.status_code == 200
        body = resp.json()
        # Health endpoint should return a status indicator. We only assert
        # that the response is a JSON object so the contract details remain
        # owned by the health route's own tests.
        assert isinstance(body, dict)


class TestLegacyPrefixGone:
    """ADR-021: legacy /mobile/* prefix is no longer served."""

    def test_legacy_health_returns_404(self, client):
        resp = client.get("/mobile/health")
        assert resp.status_code == 404

    def test_legacy_telemetry_returns_404(self, client):
        resp = client.post(
            "/mobile/telemetry/ingest",
            json={"messages": []},
            headers={"X-Internal-Service": "iot-simulator"},
        )
        assert resp.status_code == 404

    def test_legacy_auth_login_returns_404(self, client):
        resp = client.post(
            "/mobile/auth/login",
            json={"email": "x@y.z", "password": "p"},
        )
        assert resp.status_code == 404


class TestOpenApiDocs:
    """ADR-021: docs endpoints still resolve (root_path drop side-effect check)."""

    def test_openapi_schema_available(self, client):
        resp = client.get("/mobile-openapi.json")
        assert resp.status_code == 200
        spec = resp.json()
        # All mobile paths in the spec must start with /api/v1/mobile.
        paths = list(spec.get("paths", {}).keys())
        non_health_paths = [p for p in paths if p != "/"]
        assert non_health_paths, "OpenAPI spec must declare at least one mobile path"
        for path in non_health_paths:
            assert path.startswith("/api/v1/mobile"), (
                f"OpenAPI path {path!r} does not match the canonical prefix"
            )
