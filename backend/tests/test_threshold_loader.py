"""Unit tests for ``app.services.threshold_loader`` (DB-backed).

Mocks the SQLAlchemy session so the cache, projection, and fallback
behaviour can be exercised without a real Postgres connection.
"""

from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import pytest

from app.services import threshold_loader


@pytest.fixture(autouse=True)
def _reset_cache():
    """Each test starts with an empty in-memory cache."""
    threshold_loader.invalidate_cache()
    yield
    threshold_loader.invalidate_cache()


def _stub_session(value: Any) -> MagicMock:
    """Build a session whose .execute(...).fetchone() returns (value,)."""
    session = MagicMock()
    fetchone = MagicMock()
    fetchone.fetchone.return_value = (value,) if value is not None else None
    session.execute.return_value = fetchone
    return session


def _full_doc() -> dict[str, Any]:
    return {
        "version": "2.0.0",
        "vitals": {
            "heart_rate": {
                "urgent_low": 40,
                "send_low": 50,
                "watch_high": 110,
                "send_high": 130,
                "urgent_high": 131,
            },
            "spo2": {"urgent_low": 90, "send_low": 94, "watch_low": 95},
            "body_temp": {
                "urgent_low": 35.0,
                "send_low": 36.0,
                "watch_high": 37.5,
                "send_high": 39.0,
                "urgent_high": 39.1,
            },
            "resp_rate": {
                "urgent_low": 8,
                "watch_high": 20,
                "send_high": 24,
                "urgent_high": 25,
            },
            "sys_bp": {
                "urgent_low": 90,
                "send_low": 100,
                "watch_high": 139,
                "send_high": 140,
                "urgent_high": 180,
            },
            "dia_bp": {"watch_high": 89, "send_high": 90, "urgent_high": 120},
        },
        "fall_confidence_threshold": 0.5,
        "model_thresholds": {
            "health": {"warning_at": 0.35, "high_risk_true_at": 0.5, "critical_at": 0.65},
            "fall": {"fall_true_at": 0.5, "warning_at": 0.6, "critical_at": 0.85},
            "sleep": {"critical_below": 50, "poor_below": 60, "fair_below": 75, "good_below": 85},
        },
    }


class TestVitalThresholdsFromDb:
    def test_reads_heart_rate_from_db_row(self) -> None:
        session = _stub_session(_full_doc())
        v = threshold_loader.get_vital_thresholds(session)
        assert v["heart_rate"]["urgent_low"] == 40.0
        assert v["heart_rate"]["urgent_high"] == 131.0

    def test_reads_spo2_from_db_row(self) -> None:
        session = _stub_session(_full_doc())
        v = threshold_loader.get_vital_thresholds(session)
        assert v["spo2"]["urgent_low"] == 90.0
        assert v["spo2"]["send_low"] == 94.0


class TestFallbackBehaviour:
    def test_missing_row_uses_built_in_defaults(self) -> None:
        session = _stub_session(None)
        v = threshold_loader.get_vital_thresholds(session)
        assert v["heart_rate"]["urgent_low"] == 40.0
        assert v["body_temp"]["urgent_high"] == 39.1

    def test_db_exception_falls_back(self) -> None:
        session = MagicMock()
        session.execute.side_effect = RuntimeError("connection refused")
        v = threshold_loader.get_vital_thresholds(session)
        # Falls back to built-in defaults rather than raising.
        assert v["heart_rate"]["urgent_low"] == 40.0

    def test_partial_metric_block_is_merged_with_defaults(self) -> None:
        partial = _full_doc()
        partial["vitals"]["heart_rate"] = {"urgent_low": 35}  # only override one leaf
        session = _stub_session(partial)
        v = threshold_loader.get_vital_thresholds(session)
        # Override applied
        assert v["heart_rate"]["urgent_low"] == 35.0
        # Other leaves retained from defaults
        assert v["heart_rate"]["urgent_high"] == 131.0


class TestCaching:
    def test_second_call_within_ttl_does_not_hit_db(self) -> None:
        session = _stub_session(_full_doc())
        threshold_loader.get_vital_thresholds(session)
        threshold_loader.get_vital_thresholds(session)
        threshold_loader.get_vital_thresholds(session)
        # ``execute`` called exactly once across the three reads.
        assert session.execute.call_count == 1

    def test_invalidate_cache_forces_refetch(self) -> None:
        session = _stub_session(_full_doc())
        threshold_loader.get_vital_thresholds(session)
        threshold_loader.invalidate_cache()
        threshold_loader.get_vital_thresholds(session)
        assert session.execute.call_count == 2


class TestModelThresholds:
    def test_reads_health_fall_sleep_bands(self) -> None:
        session = _stub_session(_full_doc())
        m = threshold_loader.get_model_thresholds(session)
        assert m["health"]["warning_at"] == 0.35
        assert m["fall"]["critical_at"] == 0.85
        assert m["sleep"]["good_below"] == 85.0

    def test_fall_confidence_threshold_returns_db_value(self) -> None:
        session = _stub_session(_full_doc())
        assert threshold_loader.get_fall_confidence_threshold(session) == 0.5


class TestLegacyAdapter:
    def test_to_legacy_daytime_dict_projects_keys(self) -> None:
        session = _stub_session(_full_doc())
        d = threshold_loader.to_legacy_daytime_dict(session)
        assert d["hr_critical_min"] == 40
        assert d["hr_critical_max"] == 131
        assert d["spo2_critical"] == 90
        assert d["bp_sys_critical"] == 180
        assert d["bp_sys_warning"] == 140

    def test_to_legacy_sleep_dict_keeps_osa_overlay(self) -> None:
        session = _stub_session(_full_doc())
        s = threshold_loader.to_legacy_sleep_dict(session)
        assert s["spo2_critical"] == 85  # sleep override
        assert s["osa_alert_spo2_threshold"] == 88
        assert s["apnea_rr_threshold"] == 6
        assert s["nocturnal_tachy_hr"] == 120


class TestRulesVersion:
    def test_returns_db_version(self) -> None:
        session = _stub_session(_full_doc())
        assert threshold_loader.get_rules_version(session) == "2.0.0"

    def test_falls_back_when_version_missing(self) -> None:
        doc = _full_doc()
        del doc["version"]
        session = _stub_session(doc)
        assert threshold_loader.get_rules_version(session) == threshold_loader.SNAPSHOT_VERSION
