r"""
Real DB E2E tests for family relationship behavior.

Run with:
    RUN_REAL_DB_E2E=1 ./.venv/bin/python -m pytest tests/test_e2e_relationships_real_db.py -q -s
"""

from __future__ import annotations

import asyncio
import json
import os
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Iterator

import httpx
import pytest
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

BACKEND_DIR = Path(__file__).resolve().parents[1]


def _load_test_env() -> None:
    candidate_paths = [BACKEND_DIR / ".env"]
    candidate_paths.extend(parent / "backend" / ".env" for parent in BACKEND_DIR.parents)

    for candidate in candidate_paths:
        if candidate.exists():
            load_dotenv(candidate, override=False)
            break

    os.environ.setdefault("SECRET_KEY", "test-secret")


_load_test_env()

from app.core.config import settings
from app.utils.jwt import create_access_token


RUN_REAL_DB_E2E = os.getenv("RUN_REAL_DB_E2E") == "1"

pytestmark = pytest.mark.skipif(
    not RUN_REAL_DB_E2E,
    reason="Set RUN_REAL_DB_E2E=1 to run live backend/live DB E2E tests.",
)


def _build_async_client() -> httpx.AsyncClient:
    from app.main import app

    transport = httpx.ASGITransport(app=app)
    return httpx.AsyncClient(
        transport=transport,
        base_url="http://testserver",
        timeout=10.0,
    )


def _auth_headers(*, user_id: int) -> dict[str, str]:
    token = create_access_token({"user_id": user_id})
    return {"Authorization": f"Bearer {token}"}


def _insert_user(connection, *, email: str, full_name: str) -> int:
    return int(
        connection.execute(
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
                    'e2e-not-used',
                    :full_name,
                    'user',
                    TRUE,
                    TRUE
                )
                RETURNING id
                """
            ),
            {"email": email, "full_name": full_name},
        ).scalar_one()
    )


def _insert_device(connection, *, user_id: int, device_name: str) -> int:
    return int(
        connection.execute(
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
                "user_id": user_id,
                "device_name": device_name,
                "serial_number": f"family-e2e-{uuid.uuid4()}",
            },
        ).scalar_one()
    )


def _insert_relationship(
    connection,
    *,
    patient_id: int,
    caregiver_id: int,
    status: str,
    can_view_vitals: bool,
    can_receive_alerts: bool,
    can_view_location: bool,
    created_at: datetime,
    is_primary: bool = False,
    label: str | None = None,
    tags: list[dict[str, str]] | None = None,
) -> int:
    return int(
        connection.execute(
            text(
                """
                INSERT INTO user_relationships (
                    patient_id,
                    caregiver_id,
                    relationship_type,
                    is_primary,
                    status,
                    primary_relationship_label,
                    tags,
                    can_view_vitals,
                    can_receive_alerts,
                    can_view_location,
                    created_at
                )
                VALUES (
                    :patient_id,
                    :caregiver_id,
                    'family',
                    :is_primary,
                    :status,
                    :label,
                    CAST(:tags AS json),
                    :can_view_vitals,
                    :can_receive_alerts,
                    :can_view_location,
                    :created_at
                )
                RETURNING id
                """
            ),
            {
                "patient_id": patient_id,
                "caregiver_id": caregiver_id,
                "status": status,
                "is_primary": is_primary,
                "label": label,
                "tags": json.dumps(tags or []),
                "can_view_vitals": can_view_vitals,
                "can_receive_alerts": can_receive_alerts,
                "can_view_location": can_view_location,
                "created_at": created_at,
            },
        ).scalar_one()
    )


@pytest.fixture(scope="session")
def engine() -> Iterator[Engine]:
    db_engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    try:
        yield db_engine
    finally:
        db_engine.dispose()


@pytest.fixture()
def relationship_world(engine: Engine) -> Iterator[dict[str, int | str]]:
    caregiver_email = f"family-caregiver-{uuid.uuid4().hex[:12]}@example.com"
    patient_email = f"family-patient-{uuid.uuid4().hex[:12]}@example.com"
    searchable_email = f"family-target-{uuid.uuid4().hex[:12]}@example.com"
    alerts_only_email = f"family-alerts-{uuid.uuid4().hex[:12]}@example.com"
    location_only_email = f"family-location-{uuid.uuid4().hex[:12]}@example.com"
    no_device_email = f"family-nodevice-{uuid.uuid4().hex[:12]}@example.com"
    created_at = datetime.now(UTC) - timedelta(days=1)

    with engine.begin() as connection:
        caregiver_id = _insert_user(
            connection,
            email=caregiver_email,
            full_name="Family Caregiver",
        )
        patient_id = _insert_user(
            connection,
            email=patient_email,
            full_name="Family Patient",
        )
        searchable_user_id = _insert_user(
            connection,
            email=searchable_email,
            full_name="Family Search Target",
        )
        alerts_only_id = _insert_user(
            connection,
            email=alerts_only_email,
            full_name="Family Alerts Only",
        )
        location_only_id = _insert_user(
            connection,
            email=location_only_email,
            full_name="Family Location Only",
        )
        no_device_id = _insert_user(
            connection,
            email=no_device_email,
            full_name="Family No Device",
        )

        patient_device_id = _insert_device(
            connection,
            user_id=patient_id,
            device_name="Family Patient Device",
        )
        location_only_device_id = _insert_device(
            connection,
            user_id=location_only_id,
            device_name="Family No Vitals Device",
        )

        accepted_id = _insert_relationship(
            connection,
            patient_id=patient_id,
            caregiver_id=caregiver_id,
            status="accepted",
            can_view_vitals=True,
            can_receive_alerts=True,
            can_view_location=True,
            created_at=created_at,
            is_primary=True,
            label="Mẹ",
            tags=[{"id": "family", "name": "Gia đình"}],
        )
        _insert_relationship(
            connection,
            patient_id=caregiver_id,
            caregiver_id=patient_id,
            status="accepted",
            can_view_vitals=False,
            can_receive_alerts=False,
            can_view_location=False,
            created_at=created_at,
            label="Con",
            tags=[{"id": "family", "name": "Gia đình"}],
        )
        _insert_relationship(
            connection,
            patient_id=alerts_only_id,
            caregiver_id=caregiver_id,
            status="accepted",
            can_view_vitals=False,
            can_receive_alerts=True,
            can_view_location=False,
            created_at=created_at,
            label="Dì",
        )
        _insert_relationship(
            connection,
            patient_id=location_only_id,
            caregiver_id=caregiver_id,
            status="accepted",
            can_view_vitals=False,
            can_receive_alerts=False,
            can_view_location=True,
            created_at=created_at,
            label="Bác",
        )
        _insert_relationship(
            connection,
            patient_id=no_device_id,
            caregiver_id=caregiver_id,
            status="accepted",
            can_view_vitals=False,
            can_receive_alerts=True,
            can_view_location=False,
            created_at=created_at,
            label="Cậu",
        )

        connection.execute(
            text(
                """
                INSERT INTO vitals (
                    device_id,
                    time,
                    heart_rate,
                    spo2,
                    temperature,
                    blood_pressure_sys,
                    blood_pressure_dia,
                    signal_quality
                )
                VALUES (
                    :device_id,
                    :time,
                    88,
                    97,
                    36.7,
                    124,
                    80,
                    0.98
                )
                """
            ),
            {
                "device_id": patient_device_id,
                "time": datetime.now(UTC) - timedelta(minutes=2),
            },
        )

        connection.execute(
            text(
                """
                INSERT INTO sleep_sessions (
                    user_id,
                    device_id,
                    start_time,
                    end_time,
                    sleep_score,
                    wake_count,
                    phases,
                    sleep_date
                )
                VALUES (
                    :user_id,
                    :device_id,
                    :start_time,
                    :end_time,
                    82,
                    1,
                    CAST(:phases AS jsonb),
                    :sleep_date
                )
                """
            ),
            {
                "user_id": patient_id,
                "device_id": patient_device_id,
                "start_time": datetime.now(UTC) - timedelta(hours=8),
                "end_time": datetime.now(UTC) - timedelta(hours=1),
                "phases": json.dumps(
                    {"awake": 20, "light": 220, "deep": 120, "rem": 70}
                ),
                "sleep_date": datetime.now(UTC).date(),
            },
        )

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
                    :device_id,
                    :calculated_at,
                    'general',
                    82,
                    'critical',
                    :features,
                    'family-e2e-v1',
                    'rule_based'
                )
                RETURNING id
                """
            ),
            {
                "user_id": patient_id,
                "device_id": patient_device_id,
                "calculated_at": datetime.now(UTC) - timedelta(minutes=15),
                "features": json.dumps(
                    {
                        "confidence": 0.81,
                        "backend": "rule_based",
                        "raw_vitals": {
                            "heart_rate": 88,
                            "spo2": 97,
                            "blood_pressure_sys": 124,
                            "blood_pressure_dia": 80,
                            "temperature": 36.7,
                        },
                    }
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
                    'Risk elevation requires review',
                    :feature_importance,
                    'rule_based',
                    :recommendations
                )
                """
            ),
            {
                "risk_score_id": int(risk_score_id),
                "feature_importance": json.dumps({"heart_rate": 0.61, "spo2": 0.34}),
                "recommendations": json.dumps(["Check contact now", "Review vitals"]),
            },
        )

        sos_event_id = connection.execute(
            text(
                """
                INSERT INTO sos_events (
                    user_id,
                    device_id,
                    trigger_type,
                    triggered_at,
                    latitude,
                    longitude,
                    address,
                    status
                )
                VALUES (
                    :user_id,
                    :device_id,
                    'manual',
                    :triggered_at,
                    10.777,
                    106.700,
                    'Family E2E Address',
                    'active'
                )
                RETURNING id
                """
            ),
            {
                "user_id": patient_id,
                "device_id": patient_device_id,
                "triggered_at": datetime.now(UTC) - timedelta(minutes=10),
            },
        ).scalar_one()

    try:
        yield {
            "caregiver_id": caregiver_id,
            "patient_id": patient_id,
            "searchable_user_id": searchable_user_id,
            "alerts_only_id": alerts_only_id,
            "location_only_id": location_only_id,
            "no_device_id": no_device_id,
            "accepted_id": accepted_id,
            "sos_event_id": int(sos_event_id),
            "searchable_email": searchable_email,
        }
    finally:
        with engine.begin() as connection:
            connection.execute(
                text(
                    """
                    DELETE FROM risk_explanations
                    WHERE risk_score_id IN (
                        SELECT id
                        FROM risk_scores
                        WHERE user_id IN (
                            :caregiver_id,
                            :patient_id,
                            :searchable_user_id,
                            :alerts_only_id,
                            :location_only_id,
                            :no_device_id
                        )
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM risk_scores
                    WHERE user_id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM sos_events
                    WHERE user_id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM sleep_sessions
                    WHERE user_id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM vitals
                    WHERE device_id IN (
                        SELECT id
                        FROM devices
                        WHERE user_id IN (
                            :caregiver_id,
                            :patient_id,
                            :searchable_user_id,
                            :alerts_only_id,
                            :location_only_id,
                            :no_device_id
                        )
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM devices
                    WHERE user_id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM user_relationships
                    WHERE patient_id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    OR caregiver_id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )
            connection.execute(
                text(
                    """
                    DELETE FROM users
                    WHERE id IN (
                        :caregiver_id,
                        :patient_id,
                        :searchable_user_id,
                        :alerts_only_id,
                        :location_only_id,
                        :no_device_id
                    )
                    """
                ),
                {
                    "caregiver_id": caregiver_id,
                    "patient_id": patient_id,
                    "searchable_user_id": searchable_user_id,
                    "alerts_only_id": alerts_only_id,
                    "location_only_id": location_only_id,
                    "no_device_id": no_device_id,
                },
            )


def test_request_accept_update_delete_round_trip(
    relationship_world: dict[str, int | str],
) -> None:
    caregiver_id = int(relationship_world["caregiver_id"])
    searchable_user_id = int(relationship_world["searchable_user_id"])
    searchable_email = str(relationship_world["searchable_email"])

    async def _exercise() -> None:
        async with _build_async_client() as client:
            search_response = await client.get(
                "/api/v1/mobile/relationships/search",
                headers=_auth_headers(user_id=caregiver_id),
                params={"query": searchable_email},
            )
            assert search_response.status_code == 200
            assert search_response.json()[0]["connection_status"] == "none"

            request_response = await client.post(
                "/api/v1/mobile/relationships/request",
                headers=_auth_headers(user_id=caregiver_id),
                json={
                    "target_user_id": searchable_user_id,
                    "relationship_type": "family",
                    "primary_relationship_label": "Anh",
                    "tags": [{"id": "family", "name": "Gia đình"}],
                },
            )
            assert request_response.status_code == 201
            relationship_id = int(request_response.json()["id"])

            duplicate_response = await client.post(
                "/api/v1/mobile/relationships/request",
                headers=_auth_headers(user_id=caregiver_id),
                json={
                    "target_user_id": searchable_user_id,
                    "relationship_type": "family",
                },
            )
            assert duplicate_response.status_code == 400

            self_response = await client.post(
                "/api/v1/mobile/relationships/request",
                headers=_auth_headers(user_id=caregiver_id),
                json={"target_user_id": caregiver_id},
            )
            assert self_response.status_code == 400

            accept_response = await client.post(
                "/api/v1/mobile/relationships/accept",
                headers=_auth_headers(user_id=searchable_user_id),
                json={"relationship_id": relationship_id},
            )
            assert accept_response.status_code == 200
            assert accept_response.json()["status"] == "accepted"

            update_response = await client.put(
                f"/api/v1/mobile/relationships/{relationship_id}",
                headers=_auth_headers(user_id=searchable_user_id),
                json={
                    "can_view_vitals": True,
                    "can_receive_alerts": False,
                    "can_view_location": True,
                    "primary_relationship_label": "Anh ruột",
                    "tags": [{"id": "family", "name": "Gia đình"}],
                },
            )
            assert update_response.status_code == 200
            assert update_response.json()["primary_relationship_label"] == "Anh ruột"
            assert update_response.json()["can_view_location"] is True

            delete_response = await client.delete(
                f"/api/v1/mobile/relationships/{relationship_id}",
                headers=_auth_headers(user_id=searchable_user_id),
            )
            assert delete_response.status_code == 204

            search_after_delete = await client.get(
                "/api/v1/mobile/relationships/search",
                headers=_auth_headers(user_id=caregiver_id),
                params={"query": searchable_email},
            )
            assert search_after_delete.status_code == 200
            assert search_after_delete.json()[0]["connection_status"] == "none"

    asyncio.run(_exercise())


def test_access_profiles_and_dashboard_use_real_data(
    relationship_world: dict[str, int | str],
) -> None:
    caregiver_id = int(relationship_world["caregiver_id"])
    patient_id = int(relationship_world["patient_id"])
    alerts_only_id = int(relationship_world["alerts_only_id"])
    location_only_id = int(relationship_world["location_only_id"])
    no_device_id = int(relationship_world["no_device_id"])
    sos_event_id = int(relationship_world["sos_event_id"])

    async def _exercise() -> None:
        async with _build_async_client() as client:
            access_response = await client.get(
                "/api/v1/mobile/access-profiles",
                headers=_auth_headers(user_id=caregiver_id),
            )
            assert access_response.status_code == 200
            access_ids = {item["id"] for item in access_response.json()}
            assert access_ids == {
                caregiver_id,
                patient_id,
                alerts_only_id,
                location_only_id,
                no_device_id,
            }

            dashboard_response = await client.get(
                "/api/v1/mobile/relationships/dashboard",
                headers=_auth_headers(user_id=caregiver_id),
            )
            assert dashboard_response.status_code == 200
            snapshots = {
                int(item["id"]): item
                for item in dashboard_response.json()
            }

            patient_snapshot = snapshots[patient_id]
            assert patient_snapshot["relation"] == "Mẹ"
            assert patient_snapshot["risk_level"] == "critical"
            assert patient_snapshot["is_sos_active"] is True
            assert patient_snapshot["sos_id"] == str(sos_event_id)
            assert patient_snapshot["sleep_duration_minutes"] == 410
            assert patient_snapshot["sleep_quality"] == "Tốt"
            assert patient_snapshot["health_score_7_days"] == 18
            assert patient_snapshot["health_score_level"] == "Thấp"
            assert patient_snapshot["is_pinned"] is True
            assert patient_snapshot["has_vitals_data"] is True
            assert patient_snapshot["has_view_vitals_permission"] is True
            assert patient_snapshot["special_note"]

            location_only_snapshot = snapshots[location_only_id]
            assert location_only_snapshot["has_view_vitals_permission"] is False
            assert location_only_snapshot["has_vitals_data"] is False
            assert (
                location_only_snapshot["vitals_data_message"]
                == "Thiết bị đã kết nối nhưng chưa có dữ liệu đo."
            )

            no_device_snapshot = snapshots[no_device_id]
            assert no_device_snapshot["has_view_vitals_permission"] is False
            assert no_device_snapshot["has_vitals_data"] is False
            assert (
                no_device_snapshot["vitals_data_message"]
                == "Người dùng chưa kết nối thiết bị với tài khoản."
            )

    asyncio.run(_exercise())


def test_linked_contact_detail_returns_live_payload(
    relationship_world: dict[str, int | str],
) -> None:
    caregiver_id = int(relationship_world["caregiver_id"])
    patient_id = int(relationship_world["patient_id"])

    async def _exercise() -> None:
        async with _build_async_client() as client:
            detail_response = await client.get(
                f"/api/v1/mobile/relationships/{patient_id}/detail",
                headers=_auth_headers(user_id=caregiver_id),
            )

        assert detail_response.status_code == 200
        detail = detail_response.json()
        assert detail["displayName"] == "Family Patient"
        assert detail["email"].endswith("@example.com")
        assert detail["status"] == "accepted"
        assert isinstance(detail["permissions"], list)

    asyncio.run(_exercise())
