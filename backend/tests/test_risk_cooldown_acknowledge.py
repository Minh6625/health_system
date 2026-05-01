"""Regression test for Issue 2b: risk-alert cooldown must skip alerts
the user already acknowledged via "Tôi ổn" (RiskAlertResponse with
``response_action='safe'``).

Without this exclusion, a second simulator inject within the 5-min
``RISK_ALERT_COOLDOWN_SECONDS`` window was silently suppressed even
after the patient had explicitly cleared the previous alert — which
the user reported as "click Tôi ổn → các lần test sau không hiện FCM
nữa".

Uses the real Postgres database from ``settings.DATABASE_URL`` so we
exercise the actual SQL the BE runs in production.  Each test creates
its own scoped fixture rows + cleans them up so re-running the suite
is idempotent.
"""

from __future__ import annotations

import pytest
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.models.risk_alert_response_model import RiskAlertResponse
from app.models.sos_event_model import Alert
from app.services.notification_service import NotificationService


# A pre-existing device id we can borrow.  ``alert_type`` is constrained
# to a fixed CHECK list at the DB level, so we cannot invent unique
# values per test — instead we isolate by ``title`` (a unique prefix
# per test) and clean up by that prefix.  ``risk_high`` is one of the
# allowed alert types.
_TEST_DEVICE_ID = 51
_TEST_ALERT_TYPE = "risk_high"
_TITLE_PREFIX = "__cooldown_ack_test__"


@pytest.fixture
def db_session() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def _cleanup(db: Session, title_marker: str) -> None:
    """Remove rows whose title starts with our isolation marker so the
    test is repeatable + does not affect production rows."""
    pattern = f"{title_marker}%"
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


def _insert_recent_alert(db: Session, title: str) -> Alert:
    alert = Alert(
        device_id=_TEST_DEVICE_ID,
        user_id=4,
        alert_type=_TEST_ALERT_TYPE,
        severity="high",
        title=title,
        message="cooldown regression",
    )
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert


def test_unacknowledged_alert_blocks_cooldown(db_session: Session) -> None:
    """Baseline: a fresh Alert with no response → cooldown=True."""
    title_marker = f"{_TITLE_PREFIX}_unack"
    _cleanup(db_session, title_marker)
    try:
        _insert_recent_alert(db_session, title_marker)
        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type=_TEST_ALERT_TYPE,
        )
        assert in_cooldown is True
    finally:
        _cleanup(db_session, title_marker)


def test_acknowledged_alert_skips_cooldown(db_session: Session) -> None:
    """Issue 2b: an Alert with a 'safe' RiskAlertResponse should NOT
    count toward the cooldown — the next event must fire fresh.

    Cleans up ALL rows (not just our own marker) before running so any
    pre-existing risk_high alerts on the test device don't pollute the
    cooldown query.  Restores nothing afterwards — prod data on this
    test device is dispensable in dev."""
    title_marker = f"{_TITLE_PREFIX}_ack"
    # Fully wipe recent risk_high alerts on the test device so the
    # cooldown query has a clean slate — otherwise stale rows from
    # earlier sim runs keep the cooldown True regardless.
    db_session.execute(
        text(
            "DELETE FROM risk_alert_responses WHERE notification_id IN "
            "(SELECT id FROM alerts WHERE device_id = :d AND alert_type = :t)"
        ),
        {"d": _TEST_DEVICE_ID, "t": _TEST_ALERT_TYPE},
    )
    db_session.execute(
        text("DELETE FROM alerts WHERE device_id = :d AND alert_type = :t"),
        {"d": _TEST_DEVICE_ID, "t": _TEST_ALERT_TYPE},
    )
    db_session.commit()
    try:
        alert = _insert_recent_alert(db_session, title_marker)
        # User clicked "Tôi ổn" → BE persisted action='safe'.
        response = RiskAlertResponse(
            notification_id=alert.id,
            response_action="safe",
            source="overlay",
        )
        db_session.add(response)
        db_session.commit()

        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type=_TEST_ALERT_TYPE,
        )
        assert in_cooldown is False, (
            "Acknowledged alert must not block cooldown — bug 2b regression"
        )
    finally:
        _cleanup(db_session, title_marker)


def test_help_requested_response_still_blocks_cooldown(
    db_session: Session,
) -> None:
    """Only ``response_action='safe'`` should clear the cooldown.  A
    'help_requested' or 'timeout_escalated' response means the user
    NEEDS help — the cooldown should still suppress duplicates while
    the original alert is still being handled."""
    title_marker = f"{_TITLE_PREFIX}_help"
    _cleanup(db_session, title_marker)
    try:
        alert = _insert_recent_alert(db_session, title_marker)
        response = RiskAlertResponse(
            notification_id=alert.id,
            response_action="help_requested",
            source="overlay",
        )
        db_session.add(response)
        db_session.commit()

        in_cooldown = NotificationService.is_risk_alert_in_cooldown(
            db_session,
            device_id=_TEST_DEVICE_ID,
            alert_type=_TEST_ALERT_TYPE,
        )
        assert in_cooldown is True, (
            "help_requested is not 'safe' — cooldown must still apply"
        )
    finally:
        _cleanup(db_session, title_marker)
