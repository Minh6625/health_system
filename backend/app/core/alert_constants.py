"""Alert constants and escalation configuration for risk-based notifications.

This module centralises alert type identifiers, severity mapping, and
escalation rules so that every consumer (risk route, notification service,
push service) references the same source of truth.

Architecture reference: plans/alert-threshold-architecture-plan.md §4.2
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Sequence


# ---------------------------------------------------------------------------
# Alert type identifiers (stored in ``alerts.alert_type``)
# ---------------------------------------------------------------------------

ALERT_TYPE_FALL_DETECTED = "fall_detected"
ALERT_TYPE_SOS = "sos"
ALERT_TYPE_RISK_HIGH = "risk_high"
ALERT_TYPE_RISK_CRITICAL = "risk_critical"

# Convenience set for quick membership checks
RISK_ALERT_TYPES: frozenset[str] = frozenset({
    ALERT_TYPE_RISK_HIGH,
    ALERT_TYPE_RISK_CRITICAL,
})


# ---------------------------------------------------------------------------
# Caregiver "Recent alerts" feed whitelist
#
# Controls which alert_type values are surfaced on the caregiver-facing
# PersonDetailScreen "Cảnh báo gần đây" section. Intentionally narrower than
# the full canonical alert_type vocabulary:
#   * Health-relevant only — caregivers come here to assess the patient's
#     condition, not to triage device issues.
#   * Excludes ``device_offline`` / ``low_battery`` (device status belongs
#     on the device screen and otherwise creates noise).
#   * Excludes ``medication_reminder`` / ``manual_check_in`` / ``system`` /
#     ``caregiver_message`` (not health events about the patient).
# Adding/removing entries here is a product/UX decision; coordinate with the
# frontend AlertHistorySection icon mapping before changing.
# ---------------------------------------------------------------------------

ALERT_TYPE_VITAL_ABNORMAL = "vital_abnormal"
ALERT_TYPE_SOS_TRIGGERED = "sos_triggered"
ALERT_TYPE_SLEEP_ANOMALY = "sleep_anomaly"

CAREGIVER_FEED_ALERT_TYPES: frozenset[str] = frozenset({
    ALERT_TYPE_SOS_TRIGGERED,
    ALERT_TYPE_FALL_DETECTED,
    ALERT_TYPE_RISK_CRITICAL,
    ALERT_TYPE_RISK_HIGH,
    ALERT_TYPE_VITAL_ABNORMAL,
    ALERT_TYPE_SLEEP_ANOMALY,
})


# ---------------------------------------------------------------------------
# Escalation dataclass
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class EscalationRule:
    """Maps a risk level to an alert action."""

    risk_level: str
    should_alert: bool
    alert_type: str | None
    severity: str | None  # Must match Alert CHECK: 'normal', 'high', 'critical'
    title_template: str
    message_template: str
    fcm_channel: str | None  # Android notification channel


# ---------------------------------------------------------------------------
# Escalation matrix  (risk_level -> EscalationRule)
#
# Severity values MUST match the DB CHECK constraint:
#   CHECK(severity IN ('normal', 'high', 'critical'))
# ---------------------------------------------------------------------------

ESCALATION_MATRIX: dict[str, EscalationRule] = {
    "low": EscalationRule(
        risk_level="low",
        should_alert=False,
        alert_type=None,
        severity=None,
        title_template="",
        message_template="",
        fcm_channel=None,
    ),
    "medium": EscalationRule(
        risk_level="medium",
        should_alert=True,
        alert_type=ALERT_TYPE_RISK_HIGH,
        severity="high",
        title_template="\u26a0\ufe0f C\u1ea3nh b\u00e1o s\u1ee9c kh\u1ecfe",
        message_template="Ch\u1ec9 s\u1ed1 s\u1ee9c kh\u1ecfe \u1edf m\u1ee9c c\u1ea7n l\u01b0u \u00fd (risk score: {score:.0f}). Vui l\u00f2ng ki\u1ec3m tra.",
        fcm_channel="risk_alerts",
    ),
    "critical": EscalationRule(
        risk_level="critical",
        should_alert=True,
        alert_type=ALERT_TYPE_RISK_CRITICAL,
        severity="critical",
        title_template="\U0001f6a8 C\u1ea3nh b\u00e1o s\u1ee9c kh\u1ecfe kh\u1ea9n c\u1ea5p",
        message_template="Ch\u1ec9 s\u1ed1 s\u1ee9c kh\u1ecfe \u1edf m\u1ee9c nguy hi\u1ec3m (risk score: {score:.0f}). C\u1ea7n can thi\u1ec7p ngay!",
        fcm_channel="risk_critical_alerts",
    ),
}


def get_escalation_rule(risk_level: str) -> EscalationRule | None:
    """Return the escalation rule for *risk_level*, or ``None`` if no alert needed."""
    rule = ESCALATION_MATRIX.get(risk_level.lower())
    if rule is None or not rule.should_alert:
        return None
    return rule


# ---------------------------------------------------------------------------
# Alert cooldown (dedup window)
# ---------------------------------------------------------------------------

RISK_ALERT_COOLDOWN_SECONDS: int = int(
    os.getenv("RISK_ALERT_COOLDOWN_SECONDS", "300"),
)
"""Minimum seconds between two risk alerts of the same ``alert_type`` for
the same device.  Prevents notification fatigue.  Default: 5 minutes."""


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

__all__: Sequence[str] = [
    "ALERT_TYPE_FALL_DETECTED",
    "ALERT_TYPE_SOS",
    "ALERT_TYPE_SOS_TRIGGERED",
    "ALERT_TYPE_RISK_HIGH",
    "ALERT_TYPE_RISK_CRITICAL",
    "ALERT_TYPE_VITAL_ABNORMAL",
    "ALERT_TYPE_SLEEP_ANOMALY",
    "RISK_ALERT_TYPES",
    "CAREGIVER_FEED_ALERT_TYPES",
    "EscalationRule",
    "ESCALATION_MATRIX",
    "get_escalation_rule",
    "RISK_ALERT_COOLDOWN_SECONDS",
]
