"""Phase 8 (2026-05-20) regression tests for the risk-alert family cooldown
and the group-ack release behaviour added in plan
``fix-risk-score-and-fcm-spam`` parts B1 + B2.

Bug surface fixed by these tests:

* B1: ``is_risk_alert_in_cooldown`` previously gated by the exact
  ``alert_type``. With two distinct values (``risk_high``,
  ``risk_critical``) cooldowns ran in parallel — vitals oscillating
  around ``health_thresholds.critical_at`` (0.65) bounced between
  medium and critical and produced FCM pings every few dozen seconds.
  Family-level cooldown blocks any cross-type fire within the window
  except a true escalation up (medium → critical).
* B2: ``create_risk_alerts`` writes one Alert row per recipient. A
  patient pressing "Tôi ổn" only marks **their** row safe; caregiver
  rows of the same risk event stayed unacknowledged and kept the
  cooldown active. Group-ack now releases by ``risk_score_id`` so a
  single safe response clears the whole fan-out.

Tests reuse the real-Postgres pattern from
``test_risk_cooldown_acknowledge.py`` so they exercise the actual SQL
the BE runs in production. Each test creates scoped fixtures and
cleans them up so the suite stays idempotent.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.models.risk_alert_response_model import RiskAlertResponse
from app.models.sos_event_model import Alert
from app.services.notification_service import NotificationService


_TEST_DEVICE_ID = 51
_TEST_USER_ID = 4
_CAREGIVER_USER_ID = 5
_TITLE_PREFIX = "__cooldown_family_test__"


@pytest.fixture
def db_session() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _wipe_test_alerts(db: Session) -> None:
    """Clear all risk_high/risk_critical alerts on the test device so a
    test starts from a clean slate. Test device is dispensable in dev."""
    db.execute(
        text(
            "DELETE FROM risk_alert_responses WHERE notification_id IN "
            "(SELECT id FROM alerts WHERE device_id = :d "
            "AND alert_type IN ('risk_high', 'risk_critical'))"
        ),
        {"d": _TEST_DEVICE_ID},
    )
    db.execute(
        text(
            "DELETE FROM alerts WHERE device_id = :d "
            "AND alert_type IN ('risk_high', 'risk_critical')"
        ),
        {"d": _TEST_DEVICE_ID},
    )
    db.commit()


def _cleanup_by_marker(db: Session, marker: str) -> None:
    pattern = f"{marker}%"
    db.execute(
        text(
            "DELETE FROM risk_alert_responses WHERE notification_id IN "
            "(SELECT id FROM alerts WHERE title LIKE :p)"
        ),
        {"p": pattern},
    )
    db.execute(
        text("DELETE FROM alerts WHERE title LIKE :p"),
        {"p": pattern},
    )
    db.commit()


def _insert_alert(
    db: Session,
    *,
    alert_type: str,
    title: str,
    user_id: int = _TEST_USER_ID,
    risk_score_id: int | None = None,
) -> Alert:
    severity = "critical" if alert_type == "risk_critical" else "high"
    details: dict | None = None
    if risk_score_id is not None:
        details = {"risk_score_id": risk_score_id}
    alert = Alert(
        device_id=_TEST_DEVICE_ID,
        user_id=user_id,
        alert_type=alert_type,
        severity=severity,
        title=title,
        message="cooldown family regression",
        details=details,
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert


def test_family_cooldown_blocks_same_type(db_session: Session) -> None:
    """Baseline family behaviour: same-type re-fire within window blocks."""
    marker = f"{_TITLE_PREFIX}_same_type"
    _wipe_test_alerts(db_session)
    try:
        _insert_alert(db_session, alert_type="risk_high", title=marker)
        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type="risk_high",
        )
        assert in_cooldown is True
    finally:
        _cleanup_by_marker(db_session, marker)


def test_family_cooldown_allows_escalate_up(db_session: Session) -> None:
    """Phase 8 B1: medium → critical must pass cooldown so a worsening
    condition surfaces immediately even if a recent warning is unacked."""
    marker = f"{_TITLE_PREFIX}_escalate_up"
    _wipe_test_alerts(db_session)
    try:
        _insert_alert(db_session, alert_type="risk_high", title=marker)
        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type="risk_critical",
        )
        assert in_cooldown is False, (
            "Escalation medium -> critical must bypass family cooldown"
        )
    finally:
        _cleanup_by_marker(db_session, marker)


def test_family_cooldown_blocks_downgrade(db_session: Session) -> None:
    """Phase 8 B1: critical → medium downgrade must be suppressed so we
    don't ping the user again with a less-urgent alert right after a
    critical one."""
    marker = f"{_TITLE_PREFIX}_downgrade"
    _wipe_test_alerts(db_session)
    try:
        _insert_alert(db_session, alert_type="risk_critical", title=marker)
        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type="risk_high",
        )
        assert in_cooldown is True, (
            "Downgrade critical -> medium must be blocked by family cooldown"
        )
    finally:
        _cleanup_by_marker(db_session, marker)


def test_family_cooldown_blocks_cross_type_oscillation(
    db_session: Session,
) -> None:
    """Phase 8 B1: when the most recent alert in the family is a critical
    that has not yet been acked, a follow-up critical of the same type
    must still be blocked. This guards against the original spam case
    where vitals bounced between medium and critical.

    (Escalation medium -> critical is the only allowed bypass; same-type
    repeat after critical is NOT.)"""
    marker = f"{_TITLE_PREFIX}_oscillation"
    _wipe_test_alerts(db_session)
    try:
        _insert_alert(db_session, alert_type="risk_high", title=marker + "_a")
        _insert_alert(
            db_session, alert_type="risk_critical", title=marker + "_b"
        )
        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type="risk_critical",
        )
        assert in_cooldown is True, (
            "Same-type re-fire after recent critical must stay blocked"
        )
    finally:
        _cleanup_by_marker(db_session, marker)


def test_group_ack_releases_sibling_caregiver_rows(
    db_session: Session,
) -> None:
    """Phase 8 B2: when one alert in the recipient fan-out is acked
    safe, the cooldown query must treat siblings sharing the same
    ``risk_score_id`` as acked too. Otherwise patient ack does not
    release the cooldown when caregivers are also in the recipient
    list (multi-recipient fan-out reported as "click Toi on but
    still no FCM")."""
    marker = f"{_TITLE_PREFIX}_group_ack"
    _wipe_test_alerts(db_session)
    try:
        # Group has the same risk_score_id (mimics create_risk_alerts).
        risk_score_id = 9_999_001
        patient_alert = _insert_alert(
            db_session,
            alert_type="risk_high",
            title=marker + "_patient",
            user_id=_TEST_USER_ID,
            risk_score_id=risk_score_id,
        )
        _caregiver_alert = _insert_alert(
            db_session,
            alert_type="risk_high",
            title=marker + "_caregiver",
            user_id=_CAREGIVER_USER_ID,
            risk_score_id=risk_score_id,
        )
        # Patient pressed "Toi on" only on their own row.
        ack = RiskAlertResponse(
            notification_id=patient_alert.id,
            response_action="safe",
            source="overlay",
            risk_score_id=risk_score_id,
        )
        db_session.add(ack)
        db_session.commit()

        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type="risk_high",
        )
        assert in_cooldown is False, (
            "Sibling caregiver row sharing risk_score_id must release "
            "cooldown when any group member is acked safe"
        )
    finally:
        _cleanup_by_marker(db_session, marker)
