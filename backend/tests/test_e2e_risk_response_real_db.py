r"""
Real DB E2E tests for risk alert terminal responses and SOS escalation fan-out.

Run with:
    $env:RUN_REAL_DB_E2E = "1"
    .\venv\Scripts\python.exe -m pytest tests/test_e2e_risk_response_real_db.py -q -s
"""

from __future__ import annotations

import json

import httpx
import pytest
from sqlalchemy import text
from sqlalchemy.engine import Engine

from .test_e2e_manual_sos import (
    RUN_REAL_DB_E2E,
    _auth_headers,
    backend_base_url,
    emergency_users,
    engine,
)


pytestmark = pytest.mark.skipif(
    not RUN_REAL_DB_E2E,
    reason="Set RUN_REAL_DB_E2E=1 to run live backend/live DB E2E tests.",
)


def _insert_risk_alert(
    engine: Engine,
    *,
    device_id: int,
    user_id: int,
    alert_type: str,
    risk_score_id: int,
) -> int:
    with engine.begin() as connection:
        alert_id = connection.execute(
            text(
                """
                INSERT INTO alerts (
                    device_id,
                    user_id,
                    fall_event_id,
                    alert_type,
                    severity,
                    title,
                    message,
                    data
                )
                VALUES (
                    :device_id,
                    :user_id,
                    NULL,
                    :alert_type,
                    :severity,
                    :title,
                    :message,
                    CAST(:data AS jsonb)
                )
                RETURNING id
                """
            ),
            {
                "device_id": device_id,
                "user_id": user_id,
                "alert_type": alert_type,
                "severity": "critical" if alert_type == "risk_critical" else "high",
                "title": f"E2E {alert_type}",
                "message": "Risk alert terminal response test",
                "data": json.dumps(
                    {
                        "risk_level": "critical"
                        if alert_type == "risk_critical"
                        else "medium",
                        "risk_score_id": risk_score_id,
                        "escalation_stage": "initial",
                    }
                ),
            },
        ).scalar_one()
    return int(alert_id)


def test_risk_safe_response_enforces_auth_and_persists_ack(
    backend_base_url: str,
    engine: Engine,
    emergency_users: dict[str, int],
) -> None:
    patient_id = emergency_users["patient_id"]
    caregiver_id = emergency_users["caregiver_id"]
    alert_id = _insert_risk_alert(
        engine,
        device_id=emergency_users["device_id"],
        user_id=patient_id,
        alert_type="risk_high",
        risk_score_id=4101,
    )

    with httpx.Client(base_url=backend_base_url, timeout=20.0) as client:
        unauthorized = client.post(
            f"/mobile/risk/alerts/{alert_id}/respond",
            json={"action": "safe", "source": "overlay"},
        )
        assert unauthorized.status_code in {401, 403}

        forbidden = client.post(
            f"/mobile/risk/alerts/{alert_id}/respond",
            headers=_auth_headers(user_id=caregiver_id),
            json={"action": "safe", "source": "overlay"},
        )
        assert forbidden.status_code == 403, forbidden.text

        safe_response = client.post(
            f"/mobile/risk/alerts/{alert_id}/respond",
            headers=_auth_headers(user_id=patient_id),
            json={
                "risk_score_id": 4101,
                "action": "safe",
                "source": "overlay",
            },
        )
        assert safe_response.status_code == 200, safe_response.text
        safe_body = safe_response.json()
        assert safe_body["status"] == "acknowledged"
        assert safe_body["sos_event_id"] is None

        duplicate = client.post(
            f"/mobile/risk/alerts/{alert_id}/respond",
            headers=_auth_headers(user_id=patient_id),
            json={
                "risk_score_id": 4101,
                "action": "safe",
                "source": "overlay",
            },
        )
        assert duplicate.status_code == 200, duplicate.text
        assert duplicate.json()["status"] == "duplicate"

    with engine.begin() as connection:
        risk_response = connection.execute(
            text(
                """
                SELECT response_action, sos_event_id
                FROM risk_alert_responses
                WHERE notification_id = :alert_id
                """
            ),
            {"alert_id": alert_id},
        ).mappings().one()
        assert risk_response["response_action"] == "safe"
        assert risk_response["sos_event_id"] is None


def test_risk_escalation_creates_vital_critical_sos_for_caregiver(
    backend_base_url: str,
    engine: Engine,
    emergency_users: dict[str, int],
) -> None:
    patient_id = emergency_users["patient_id"]
    caregiver_id = emergency_users["caregiver_id"]
    help_alert_id = _insert_risk_alert(
        engine,
        device_id=emergency_users["device_id"],
        user_id=patient_id,
        alert_type="risk_critical",
        risk_score_id=5101,
    )
    timeout_alert_id = _insert_risk_alert(
        engine,
        device_id=emergency_users["device_id"],
        user_id=patient_id,
        alert_type="risk_critical",
        risk_score_id=5102,
    )

    with httpx.Client(base_url=backend_base_url, timeout=20.0) as client:
        help_response = client.post(
            f"/mobile/risk/alerts/{help_alert_id}/respond",
            headers=_auth_headers(user_id=patient_id),
            json={
                "risk_score_id": 5101,
                "action": "help_requested",
                "source": "overlay",
                "address": "Risk escalation help requested",
            },
        )
        assert help_response.status_code == 200, help_response.text
        help_body = help_response.json()
        assert help_body["status"] == "escalated"
        assert help_body["recipient_count"] == 1
        help_sos_id = int(help_body["sos_event_id"])

        caregiver_active_list = client.get(
            "/mobile/emergency/caregiver/sos-alerts",
            headers=_auth_headers(user_id=caregiver_id),
            params={"status": "active"},
        )
        assert caregiver_active_list.status_code == 200, caregiver_active_list.text
        assert any(
            int(item["sos_id"]) == help_sos_id
            and item["trigger_type"] == "vital_critical"
            for item in caregiver_active_list.json()["sos_alerts"]
        )

        help_detail = client.get(
            f"/mobile/emergency/sos/{help_sos_id}",
            headers=_auth_headers(user_id=caregiver_id),
        )
        assert help_detail.status_code == 200, help_detail.text
        assert help_detail.json()["trigger_type"] == "vital_critical"

        duplicate = client.post(
            f"/mobile/risk/alerts/{help_alert_id}/respond",
            headers=_auth_headers(user_id=patient_id),
            json={
                "risk_score_id": 5101,
                "action": "help_requested",
                "source": "overlay",
            },
        )
        assert duplicate.status_code == 200, duplicate.text
        assert duplicate.json()["status"] == "duplicate"
        assert int(duplicate.json()["sos_event_id"]) == help_sos_id

        timeout_response = client.post(
            f"/mobile/risk/alerts/{timeout_alert_id}/respond",
            headers=_auth_headers(user_id=patient_id),
            json={
                "risk_score_id": 5102,
                "action": "timeout_escalated",
                "source": "push_tap",
                "address": "Risk escalation timeout",
            },
        )
        assert timeout_response.status_code == 200, timeout_response.text
        timeout_body = timeout_response.json()
        assert timeout_body["status"] == "escalated"
        assert timeout_body["recipient_count"] == 1
        timeout_sos_id = int(timeout_body["sos_event_id"])

        timeout_detail = client.get(
            f"/mobile/emergency/sos/{timeout_sos_id}",
            headers=_auth_headers(user_id=caregiver_id),
        )
        assert timeout_detail.status_code == 200, timeout_detail.text
        assert timeout_detail.json()["trigger_type"] == "vital_critical"

    with engine.begin() as connection:
        help_response_row = connection.execute(
            text(
                """
                SELECT response_action, sos_event_id
                FROM risk_alert_responses
                WHERE notification_id = :alert_id
                """
            ),
            {"alert_id": help_alert_id},
        ).mappings().one()
        assert help_response_row["response_action"] == "help_requested"
        assert int(help_response_row["sos_event_id"]) == help_sos_id

        caregiver_sos_alert = connection.execute(
            text(
                """
                SELECT alert_type, data ->> 'sos_id' AS linked_sos_id
                FROM alerts
                WHERE user_id = :caregiver_id
                  AND alert_type = 'sos'
                  AND data ->> 'sos_id' = :linked_sos_id
                """
            ),
            {
                "caregiver_id": caregiver_id,
                "linked_sos_id": str(help_sos_id),
            },
        ).mappings().one()
        assert caregiver_sos_alert["alert_type"] == "sos"
