"""Regression test for XR-002 — severity CheckConstraint alignment per ADR-015.

Verifies:
1. _map_alert_severity maps IoT outbound vocab to canonical DB vocab.
2. All mapped values are within canonical set {low, medium, high, critical}.
"""

from __future__ import annotations

import pytest

from app.api.routes.telemetry import _map_alert_severity


CANONICAL_SEVERITY_SET = {"low", "medium", "high", "critical"}


class TestMapAlertSeverity:
    """ADR-015 Layer 2 -> Layer 4 mapping contract."""

    @pytest.mark.parametrize(
        "input_val,expected",
        [
            ("normal", "low"),
            ("Normal", "low"),
            ("NORMAL", "low"),
            ("warning", "high"),
            ("Warning", "high"),
            ("critical", "critical"),
            ("CRITICAL", "critical"),
            ("high", "high"),
            ("medium", "medium"),
            ("", "low"),
            (None, "low"),
            ("unknown_value", "low"),
        ],
    )
    def test_mapping(self, input_val, expected):
        result = _map_alert_severity(input_val)
        assert result == expected
        assert result in CANONICAL_SEVERITY_SET

    def test_all_outputs_in_canonical_set(self):
        """Every possible output must be in canonical set."""
        test_inputs = [
            "normal",
            "warning",
            "critical",
            "high",
            "medium",
            "",
            None,
            "offline",
            "garbage",
            "  Normal  ",
        ]
        for inp in test_inputs:
            result = _map_alert_severity(inp)
            assert result in CANONICAL_SEVERITY_SET, f"Input {inp!r} -> {result!r} not in canonical"
