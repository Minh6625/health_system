r"""
Real E2E tests for analysis risk read surfaces against a live backend and live Postgres.

Run with:
    $env:RUN_REAL_DB_E2E = "1"
    .\venv\Scripts\python.exe -m pytest tests/test_e2e_analysis_risk_read_surfaces.py -q -s
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
import uuid
from contextlib import closing
from datetime import UTC, datetime, timedelta
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


def _auth_headers(*, user_id: int, target_profile_id: int | None = None) -> dict[str, str]:
    token = create_access_token({"user_id": user_id})
    headers = {"Authorization": f"Bearer {token}"}
    if target_profile_id is not None:
        headers["X-Target-Profile-Id"] = str(target_profile_id)
    return headers


def _risk_features(*, confidence: float, heart_rate: int, spo2: int) -> dict[str, object]:
    return {
        "confidence": confidence,
        "backend": "rule_based",
        "model_features": {
            "heart_rate": heart_rate,
            "spo2": spo2,
            "sys_bp": 138,
            "dia_bp": 84,
            "body_temp": 36.9,
            "hrv": 28,
            "map_val": 102,
        },
        "raw_vitals": {
            "heart_rate": heart_rate,
            "spo2": spo2,
            "blood_pressure_sys": 138,
            "blood_pressure_dia": 84,
            "temperature": 36.9,
            "hrv": 28,
        },
    }


def _insert_risk_row(
    engine: Engine,
    *,
    user_id: int,
    calculated_at: datetime,
    score: float,
    risk_level: str,
    explanation_text: str,
    recommendations: list[str],
    confidence: float,
) -> int:
    with engine.begin() as connection:
        risk_score_id = connection.execute(
            text(
                """
                INSERT INTO risk_scores (
                    user_id,
                    device_id,
                    calculated_at,
                    risk_type,
                    score,
                    risk_level,
                    features,
                    model_version,
                    algorithm
                )
                VALUES (
                    :user_id,
                    NULL,
                    :calculated_at,
                    'general',
                    :score,
                    :risk_level,
                    :features,
                    'e2e-v1',
                    'rule_based'
                )
                RETURNING id
                """
            ),
            {
                "user_id": user_id,
                "calculated_at": calculated_at,
                "score": score,
                "risk_level": risk_level,
                "features": json.dumps(
                    _risk_features(
                        confidence=confidence,
                        heart_rate=108 if risk_level == "critical" else 96,
                        spo2=93 if risk_level == "critical" else 97,
                    )
                ),
            },
        ).scalar_one()

        connection.execute(
            text(
                """
                INSERT INTO risk_explanations (
                    risk_score_id,
                    explanation_text,
                    feature_importance,
                    xai_method,
                    recommendations
                )
                VALUES (
                    :risk_score_id,
                    :explanation_text,
                    :feature_importance,
                    'rule_based',
                    :recommendations
                )
                """
            ),
            {
                "risk_score_id": int(risk_score_id),
                "explanation_text": explanation_text,
                "feature_importance": json.dumps({"heart_rate": 0.62, "spo2": 0.41}),
                "recommendations": recommendations,
            },
        )

    return int(risk_score_id)


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
def temp_patient(engine: Engine) -> Iterator[dict[str, int]]:
    patient_email = f"risk-e2e-patient-{uuid.uuid4().hex[:12]}@example.com"

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
                "full_name": "Risk E2E Patient",
            },
        ).scalar_one()

    try:
        yield {"user_id": int(patient_id)}
    finally:
        with engine.begin() as connection:
            connection.execute(
                text(
                    """
                    DELETE FROM risk_explanations
                    WHERE risk_score_id IN (
                        SELECT id FROM risk_scores WHERE user_id = :user_id
                    )
                    """
                ),
                {"user_id": int(patient_id)},
            )
            connection.execute(
                text("DELETE FROM risk_scores WHERE user_id = :user_id"),
                {"user_id": int(patient_id)},
            )
            connection.execute(
                text("DELETE FROM user_relationships WHERE patient_id = :user_id"),
                {"user_id": int(patient_id)},
            )
            connection.execute(
                text("DELETE FROM users WHERE id = :user_id"),
                {"user_id": int(patient_id)},
            )


@pytest.fixture(scope="session")
def temp_caregiver(engine: Engine) -> Iterator[dict[str, int]]:
    caregiver_email = f"risk-e2e-caregiver-{uuid.uuid4().hex[:12]}@example.com"

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
                "full_name": "Risk E2E Caregiver",
            },
        ).scalar_one()

    try:
        yield {"user_id": int(caregiver_id)}
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM user_relationships WHERE caregiver_id = :user_id"),
                {"user_id": int(caregiver_id)},
            )
            connection.execute(
                text("DELETE FROM users WHERE id = :user_id"),
                {"user_id": int(caregiver_id)},
            )


@pytest.fixture(autouse=True)
def clean_analysis_rows(
    engine: Engine,
    temp_patient: dict[str, int],
    temp_caregiver: dict[str, int],
) -> Iterator[None]:
    patient_id = temp_patient["user_id"]
    caregiver_id = temp_caregiver["user_id"]
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                DELETE FROM risk_explanations
                WHERE risk_score_id IN (
                    SELECT id FROM risk_scores WHERE user_id = :patient_id
                )
                """
            ),
            {"patient_id": patient_id},
        )
        connection.execute(
            text("DELETE FROM risk_scores WHERE user_id = :patient_id"),
            {"patient_id": patient_id},
        )
        connection.execute(
            text(
                """
                DELETE FROM user_relationships
                WHERE patient_id = :patient_id OR caregiver_id = :caregiver_id
                """
            ),
            {"patient_id": patient_id, "caregiver_id": caregiver_id},
        )
    yield
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                DELETE FROM risk_explanations
                WHERE risk_score_id IN (
                    SELECT id FROM risk_scores WHERE user_id = :patient_id
                )
                """
            ),
            {"patient_id": patient_id},
        )
        connection.execute(
            text("DELETE FROM risk_scores WHERE user_id = :patient_id"),
            {"patient_id": patient_id},
        )
        connection.execute(
            text(
                """
                DELETE FROM user_relationships
                WHERE patient_id = :patient_id OR caregiver_id = :caregiver_id
                """
            ),
            {"patient_id": patient_id, "caregiver_id": caregiver_id},
        )


def test_analysis_risk_routes_return_empty_canonical_payloads_when_patient_has_no_rows(
    backend_base_url: str,
    temp_patient: dict[str, int],
) -> None:
    headers = _auth_headers(user_id=temp_patient["user_id"])

    with httpx.Client(timeout=10.0, headers=headers) as client:
        latest_response = client.get(f"{backend_base_url}/mobile/analysis/risk-reports", params={"limit": 1})
        history_response = client.get(
            f"{backend_base_url}/mobile/analysis/risk-history",
            params={"range": "7d", "page": 1, "limit": 20},
        )

    assert latest_response.status_code == 200, latest_response.text
    assert history_response.status_code == 200, history_response.text
    assert latest_response.json() == []
    assert history_response.json() == {
        "range": "7d",
        "summary": {
            "average_score": 0.0,
            "highest_score": 0.0,
            "lowest_score": 0.0,
            "delta_vs_previous_period": 0.0,
            "trend_points": [0, 0, 0, 0, 0, 0, 0],
        },
        "items": [],
        "page": 1,
        "limit": 20,
        "has_more": False,
    }


def test_analysis_risk_routes_support_self_latest_detail_history_stale_and_pagination(
    backend_base_url: str,
    engine: Engine,
    temp_patient: dict[str, int],
) -> None:
    patient_id = temp_patient["user_id"]
    now = datetime.now(UTC).replace(microsecond=0)

    _insert_risk_row(
        engine,
        user_id=patient_id,
        calculated_at=now - timedelta(days=45),
        score=22.0,
        risk_level="low",
        explanation_text="On dinh trong giai doan cu.",
        recommendations=["Tiep tuc theo doi dinh ky."],
        confidence=0.85,
    )
    _insert_risk_row(
        engine,
        user_id=patient_id,
        calculated_at=now - timedelta(days=12),
        score=46.0,
        risk_level="medium",
        explanation_text="Can theo doi sat hon trong 30 ngay qua.",
        recommendations=["Ngu du giac hon."],
        confidence=0.72,
    )
    medium_report_id = _insert_risk_row(
        engine,
        user_id=patient_id,
        calculated_at=now - timedelta(days=2),
        score=58.0,
        risk_level="medium",
        explanation_text="Chi so co dau hieu tang nhe.",
        recommendations=["Bo sung nuoc va nghi ngoi."],
        confidence=0.78,
    )
    latest_report_id = _insert_risk_row(
        engine,
        user_id=patient_id,
        calculated_at=now - timedelta(hours=8),
        score=88.0,
        risk_level="critical",
        explanation_text="Chi so tim mach dang can theo doi sat.",
        recommendations=["Nghi ngoi va do lai.", "Theo doi SpO2 trong ngay."],
        confidence=0.91,
    )

    headers = _auth_headers(user_id=patient_id)
    with httpx.Client(timeout=10.0, headers=headers) as client:
        latest_response = client.get(f"{backend_base_url}/mobile/analysis/risk-reports", params={"limit": 1})
        detail_response = client.get(f"{backend_base_url}/mobile/analysis/risk-reports/{latest_report_id}")
        history_page_1 = client.get(
            f"{backend_base_url}/mobile/analysis/risk-history",
            params={"range": "30d", "page": 1, "limit": 1},
        )
        history_page_2 = client.get(
            f"{backend_base_url}/mobile/analysis/risk-history",
            params={"range": "30d", "page": 2, "limit": 1},
        )
        history_page_3 = client.get(
            f"{backend_base_url}/mobile/analysis/risk-history",
            params={"range": "30d", "page": 3, "limit": 1},
        )

    assert latest_response.status_code == 200, latest_response.text
    assert detail_response.status_code == 200, detail_response.text
    assert history_page_1.status_code == 200, history_page_1.text
    assert history_page_2.status_code == 200, history_page_2.text
    assert history_page_3.status_code == 200, history_page_3.text

    latest_payload = latest_response.json()
    detail_payload = detail_response.json()
    history_payload_1 = history_page_1.json()
    history_payload_2 = history_page_2.json()
    history_payload_3 = history_page_3.json()

    assert len(latest_payload) == 1
    assert latest_payload[0]["id"] == latest_report_id
    assert latest_payload[0]["risk_level"] == "critical"
    assert latest_payload[0]["display_status"] == "Nguy hiểm"
    assert latest_payload[0]["health_score"] == 12.0
    assert latest_payload[0]["previous_score"] == 58.0
    assert latest_payload[0]["is_stale"] is True

    assert detail_payload["id"] == latest_report_id
    assert detail_payload["display_status"] == "Nguy hiểm"
    assert detail_payload["health_score"] == 12.0
    assert detail_payload["previous_score"] == 58.0
    assert detail_payload["snapshot"]["heart_rate"] == 108
    assert detail_payload["breakdown"][0]["contribution_score"] == 0.62
    assert detail_payload["recommendation_preview"] == ["Nghi ngoi va do lai.", "Theo doi SpO2 trong ngay."]
    assert detail_payload["is_stale"] is True

    assert history_payload_1["range"] == "30d"
    assert history_payload_1["page"] == 1
    assert history_payload_1["limit"] == 1
    assert history_payload_1["has_more"] is True
    assert history_payload_1["items"][0]["report_id"] == latest_report_id
    assert history_payload_1["items"][0]["display_status"] == "Nguy hiểm"
    assert history_payload_1["items"][0]["is_stale"] is True
    assert history_payload_1["summary"]["highest_score"] == 88.0
    assert history_payload_1["summary"]["average_score"] > 0

    assert history_payload_2["items"][0]["report_id"] == medium_report_id
    assert history_payload_2["items"][0]["display_status"] == "Cần theo dõi"
    assert history_payload_2["has_more"] is True
    assert history_payload_3["has_more"] is False


def test_analysis_risk_routes_require_relationship_for_linked_profile_then_share_same_contract(
    backend_base_url: str,
    engine: Engine,
    temp_patient: dict[str, int],
    temp_caregiver: dict[str, int],
) -> None:
    patient_id = temp_patient["user_id"]
    caregiver_id = temp_caregiver["user_id"]
    latest_report_id = _insert_risk_row(
        engine,
        user_id=patient_id,
        calculated_at=datetime.now(UTC).replace(microsecond=0) - timedelta(hours=7),
        score=88.0,
        risk_level="critical",
        explanation_text="Chi so tim mach dang can theo doi sat.",
        recommendations=["Nghi ngoi va do lai.", "Theo doi SpO2 trong ngay."],
        confidence=0.91,
    )

    linked_headers = _auth_headers(
        user_id=caregiver_id,
        target_profile_id=patient_id,
    )
    with httpx.Client(timeout=10.0, headers=linked_headers) as client:
        forbidden_response = client.get(f"{backend_base_url}/mobile/analysis/risk-reports", params={"limit": 1})

    assert forbidden_response.status_code == 403, forbidden_response.text

    with engine.begin() as connection:
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
                    FALSE,
                    FALSE
                )
                """
            ),
            {
                "patient_id": patient_id,
                "caregiver_id": caregiver_id,
            },
        )

    with httpx.Client(timeout=10.0, headers=linked_headers) as client:
        latest_response = client.get(f"{backend_base_url}/mobile/analysis/risk-reports", params={"limit": 1})
        detail_response = client.get(f"{backend_base_url}/mobile/analysis/risk-reports/{latest_report_id}")
        history_response = client.get(
            f"{backend_base_url}/mobile/analysis/risk-history",
            params={"range": "7d", "page": 1, "limit": 20},
        )

    assert latest_response.status_code == 200, latest_response.text
    assert detail_response.status_code == 200, detail_response.text
    assert history_response.status_code == 200, history_response.text
    assert latest_response.json()[0]["id"] == latest_report_id
    assert latest_response.json()[0]["display_status"] == "Nguy hiểm"
    assert detail_response.json()["id"] == latest_report_id
    assert history_response.json()["items"][0]["report_id"] == latest_report_id
