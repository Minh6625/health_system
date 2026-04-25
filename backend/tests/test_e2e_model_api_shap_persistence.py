r"""End-to-end gated test for the model-api + SHAP persistence pipeline (P2 #10).

This test exercises the new behavior introduced by P0 #2 + P1 #3:

1. ``calculate_device_risk`` calls ``healthguard-model-api`` over HTTP.
2. The real LightGBM + SHAP response is persisted to ``risk_scores`` /
   ``risk_explanations``.
3. ``algorithm = "model_api_health"``, ``xai_method = "shap"`` and the
   ``top_features_json`` / ``shap_details_json`` / ``ai_explanation_json``
   columns contain the model-api payload (not synthesized rule-based stubs).

Run with:

    # 1. start healthguard-model-api on :8001
    # 2. start health_system backend on :8000
    $env:RUN_MODEL_API_E2E = "1"
    .\venv\Scripts\python.exe -m pytest tests/test_e2e_model_api_shap_persistence.py -q -s
"""

from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone

import httpx
import pytest
from sqlalchemy import create_engine, text


RUN_MODEL_API_E2E = os.getenv("RUN_MODEL_API_E2E") == "1"
BACKEND_URL = os.getenv("HEALTH_BACKEND_URL", "http://127.0.0.1:8000")
MODEL_API_URL = os.getenv("HEALTHGUARD_MODEL_API_URL", "http://127.0.0.1:8001")

# Seeded patient + active device used by the existing E2E harness.
PATIENT_USER_ID = int(os.getenv("E2E_PATIENT_USER_ID", "4"))
PATIENT_DEVICE_ID = int(os.getenv("E2E_PATIENT_DEVICE_ID", "51"))


pytestmark = pytest.mark.skipif(
    not RUN_MODEL_API_E2E,
    reason="Set RUN_MODEL_API_E2E=1 to run the model-api SHAP persistence E2E test.",
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _model_api_alive() -> bool:
    try:
        response = httpx.get(f"{MODEL_API_URL}/api/v1/health/model-info", timeout=2.0)
    except Exception:
        return False
    if response.status_code != 200:
        return False
    payload = response.json() if response.content else {}
    return str(payload.get("status", "")).lower() == "loaded"


def _backend_alive() -> bool:
    try:
        response = httpx.get(f"{BACKEND_URL}/mobile/health", timeout=2.0)
    except Exception:
        return False
    return response.status_code == 200


def _ingest_critical_vitals() -> dict:
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
    response = httpx.post(
        f"{BACKEND_URL}/mobile/telemetry/ingest", json=payload, timeout=15.0
    )
    response.raise_for_status()
    return response.json()


def _query_latest_risk(*, since_iso: str) -> dict:
    from app.core.config import settings  # imported lazily

    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    with engine.connect() as conn:
        row = conn.execute(
            text(
                """
                SELECT
                    rs.id,
                    rs.algorithm,
                    rs.model_version,
                    rs.risk_level,
                    rs.score,
                    rs.calculated_at,
                    rs.features,
                    re.xai_method,
                    re.feature_importance,
                    re.recommendations,
                    re.top_features_json,
                    re.ai_explanation_json,
                    re.shap_details_json
                FROM risk_scores rs
                LEFT JOIN risk_explanations re ON re.risk_score_id = rs.id
                WHERE rs.user_id = :user_id
                  AND rs.calculated_at >= :since
                ORDER BY rs.calculated_at DESC
                LIMIT 1
                """
            ),
            {"user_id": PATIENT_USER_ID, "since": since_iso},
        ).mappings().first()
    return dict(row) if row else {}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def services_alive() -> None:
    if not _backend_alive():
        pytest.fail(
            f"health_system backend not reachable at {BACKEND_URL} (start uvicorn :8000)"
        )
    if not _model_api_alive():
        pytest.fail(
            f"healthguard-model-api not reachable / not loaded at {MODEL_API_URL}"
            " (start uvicorn :8001 and confirm /api/v1/health/model-info status=loaded)"
        )


def test_critical_vitals_persist_real_model_api_shap(services_alive: None) -> None:
    """End-to-end: critical vitals -> model-api -> real SHAP persisted to DB."""
    cutoff = datetime.now(timezone.utc).replace(microsecond=0)
    body = _ingest_critical_vitals()
    assert body["ingested"] >= 1, body
    assert body.get("errors") in (None, []), body

    # Backend commits the risk_score synchronously inside the same request,
    # but allow a small grace period for the row to be visible via a fresh
    # connection.
    time.sleep(1.0)

    row = _query_latest_risk(since_iso=cutoff.isoformat())
    assert row, "No risk_score persisted after critical vitals ingestion"

    # ---- Algorithm + version ----
    assert row["algorithm"] == "model_api_health", row
    assert row["model_version"] in {"v_current", "model_api_v1"}, row

    # ---- Risk level + score ----
    assert row["risk_level"] in {"medium", "critical"}, row
    assert float(row["score"]) > 0.0

    # ---- Real SHAP payloads ----
    assert row["xai_method"] == "shap", row

    top = row["top_features_json"]
    if isinstance(top, str):
        top = json.loads(top)
    assert isinstance(top, list) and top, "top_features_json must contain at least one entry"
    first = top[0]
    assert "feature" in first and "impact" in first and "direction" in first, first
    assert first["direction"] in {"risk_up", "risk_down"}

    shap_payload = row["shap_details_json"]
    if isinstance(shap_payload, str):
        shap_payload = json.loads(shap_payload)
    assert isinstance(shap_payload, dict), shap_payload
    assert shap_payload.get("available") is True, shap_payload
    values = shap_payload.get("values") or []
    assert isinstance(values, list) and len(values) >= 5, shap_payload

    explanation = row["ai_explanation_json"]
    if isinstance(explanation, str):
        explanation = json.loads(explanation)
    assert isinstance(explanation, dict), explanation
    short = (explanation.get("short_text") or "").strip()
    assert short, "ai_explanation_json.short_text must be non-empty"
    actions = explanation.get("recommended_actions") or []
    assert isinstance(actions, list) and actions, explanation


def test_repeated_ingest_rotates_or_skips_via_cooldown(services_alive: None) -> None:
    """Sanity: a second identical ingest within the cooldown does not regress
    the previous SHAP-persisted risk row to a rule-based one."""
    cutoff_initial = datetime.now(timezone.utc).replace(microsecond=0)
    _ingest_critical_vitals()
    time.sleep(0.5)
    _ingest_critical_vitals()
    time.sleep(1.0)

    row = _query_latest_risk(since_iso=cutoff_initial.isoformat())
    assert row, "Expected at least one risk_score after repeated ingest"
    # Whether cooldown skipped the second alert or not, the latest persisted
    # row should still come from the model-api path.
    assert row["algorithm"] == "model_api_health", row
    assert row["xai_method"] == "shap", row
