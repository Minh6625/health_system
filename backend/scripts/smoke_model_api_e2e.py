"""End-to-end smoke for the new model-api + SHAP persistence path.

Workflow:
  1. POST /api/v1/mobile/telemetry/ingest for the seeded patient device (id=51).
  2. Backend pipeline -> calculate_device_risk -> ModelApiClient.predict_health_risk
     -> healthguard-model-api (LightGBM + SHAP) at :8001.
  3. Query the latest risk_scores + risk_explanations rows to assert that the
     real model-api backend label, top_features_json, ai_explanation_json, and
     shap_details_json were persisted.

Run with backend venv from `backend/`:
    $env:PYTHONPATH = (Get-Location).Path
    .\venv\Scripts\python.exe scripts\smoke_model_api_e2e.py
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


def _ingest_vitals() -> None:
    payload = {
        "messages": [
            {
                "db_device_id": PATIENT_DEVICE_ID,
                "emitted_at": _now_iso(),
                "vitals": {
                    "heart_rate": 118,
                    "spo2": 92.5,
                    "temperature": 38.2,
                    "hrv": 24,
                    "respiratory_rate": 24,
                    "blood_pressure_sys": 148,
                    "blood_pressure_dia": 96,
                    "signal_quality": 0.95,
                    "motion_artifact": False,
                },
            }
        ]
    }
    print("== ingest vitals ==")
    response = httpx.post(
        f"{BACKEND_URL}/api/v1/mobile/telemetry/ingest", json=payload, timeout=15.0
    )
    print("status:", response.status_code)
    print("body:  ", response.json())


def _query_latest_risk() -> dict:
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
                    rs.calculated_at::text AS calculated_at,
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
                ORDER BY rs.calculated_at DESC
                LIMIT 1
                """
            ),
            {"user_id": PATIENT_USER_ID},
        ).mappings().first()
    return dict(row) if row else {}


def _summarize(row: dict) -> None:
    if not row:
        print("!! No risk_score persisted")
        return

    print("\n== latest risk_score ==")
    print("id:               ", row["id"])
    print("algorithm:        ", row["algorithm"])
    print("model_version:    ", row["model_version"])
    print("risk_level:       ", row["risk_level"])
    print("score:            ", float(row["score"]))
    print("xai_method:       ", row["xai_method"])

    top = row.get("top_features_json")
    print("top_features_json:")
    if isinstance(top, list) and top:
        for entry in top[:3]:
            print("  -", entry.get("feature"), "impact=", entry.get("impact"),
                  "direction=", entry.get("direction"))
    else:
        print("  <empty / null>")

    ai = row.get("ai_explanation_json") or {}
    print("ai_explanation_json.short_text:", ai.get("short_text") if isinstance(ai, dict) else None)
    print("ai_explanation_json.recommended_actions:",
          ai.get("recommended_actions") if isinstance(ai, dict) else None)

    shap = row.get("shap_details_json")
    if isinstance(shap, dict):
        print("shap_details_json.available:    ", shap.get("available"))
        print("shap_details_json.output_space: ", shap.get("output_space"))
        print("shap_details_json.values count: ", len(shap.get("values") or []))
    else:
        print("shap_details_json: <empty / null>")

    features = row.get("features") or {}
    if isinstance(features, str):
        features = json.loads(features)
    print("features.backend:        ", features.get("backend"))
    print("features.confidence:     ", features.get("confidence"))


def main() -> None:
    _ingest_vitals()
    time.sleep(1.0)  # let auto risk calc commit
    row = _query_latest_risk()
    _summarize(row)


if __name__ == "__main__":
    main()
