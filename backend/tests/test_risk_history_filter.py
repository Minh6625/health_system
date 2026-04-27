"""Tests for the optional ``risk_type`` filter on ``GET /risk-history``.

Phase 4A-full slice 3b. The mobile risk-history screen renders a chip
row over "All" / "Sức khỏe" (general) / "Giấc ngủ" (sleep) / "Té ngã"
(fall); when the user taps a non-All chip the Flutter repository
appends ``?risk_type=<value>`` to the request and the route narrows
the SQL accordingly.

These tests exercise the service-layer SQL composition in isolation
(no live route, no live DB) — the goal is to pin:

1. Which values land in the WHERE clause (only the allow-list).
2. Which don't (typos / unknown values fall back to "no filter").
3. That the count query mirrors the list query so pagination stays
   accurate.
"""

from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import MagicMock

from app.services.monitoring_service import MonitoringService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class _CapturingDb:
    """Records every ``db.execute(text, params)`` call so a test can
    introspect the SQL string + bind params without a real database.

    Returns a fixed scalar (=0) for the COUNT query and an empty list
    for the SELECT — the filter logic doesn't depend on row content,
    only on how the WHERE clause is composed.
    """

    def __init__(self) -> None:
        self.calls: list[tuple[str, dict]] = []

    def execute(self, stmt, params=None):
        sql = str(stmt)
        self.calls.append((sql, dict(params or {})))
        result = MagicMock()
        # COUNT branch returns 0; SELECT branch returns empty mappings.
        result.scalar.return_value = 0
        result.mappings.return_value.all.return_value = []
        return result


def _list_sql_call(db: _CapturingDb) -> tuple[str, dict]:
    """Return the (sql, params) for the SELECT call (skipping COUNT)."""
    for sql, params in db.calls:
        if "ORDER BY rs.calculated_at" in sql:
            return sql, params
    raise AssertionError(f"no SELECT call captured among {len(db.calls)} executions")


def _count_sql_call(db: _CapturingDb) -> tuple[str, dict]:
    for sql, params in db.calls:
        if "COUNT(*)" in sql:
            return sql, params
    raise AssertionError(f"no COUNT call captured among {len(db.calls)} executions")


# ---------------------------------------------------------------------------
# Allow-list
# ---------------------------------------------------------------------------


class TestRiskHistoryTypeFiltersAllowList:
    def test_canonical_filter_set(self) -> None:
        # The mobile chip row binds to these exact strings; expanding
        # this set requires a coordinated mobile + backend change.
        assert MonitoringService.RISK_HISTORY_TYPE_FILTERS == {
            "general", "sleep", "fall",
        }


# ---------------------------------------------------------------------------
# SQL composition
# ---------------------------------------------------------------------------


class TestRiskHistoryFilterAppliedSql:
    def test_no_risk_type_omits_the_where_clause(self) -> None:
        db = _CapturingDb()

        MonitoringService.get_risk_history(patient_id=7, db=db)

        sql, params = _list_sql_call(db)
        assert "rs.risk_type =" not in sql
        assert "risk_type" not in params

        count_sql, count_params = _count_sql_call(db)
        assert "risk_type =" not in count_sql
        assert "risk_type" not in count_params

    def test_explicit_general_filter_lands_in_sql_and_params(self) -> None:
        db = _CapturingDb()

        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="general",
        )

        sql, params = _list_sql_call(db)
        assert "rs.risk_type = :risk_type" in sql
        assert params["risk_type"] == "general"

        count_sql, count_params = _count_sql_call(db)
        # Pagination total MUST mirror the list filter — otherwise
        # ``has_more`` would be wrong on filtered pages.
        assert "risk_type = :risk_type" in count_sql
        assert count_params["risk_type"] == "general"

    def test_sleep_filter_lands_with_the_canonical_value(self) -> None:
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="sleep",
        )
        _, params = _list_sql_call(db)
        assert params["risk_type"] == "sleep"

    def test_fall_filter_lands_with_the_canonical_value(self) -> None:
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="fall",
        )
        _, params = _list_sql_call(db)
        assert params["risk_type"] == "fall"

    def test_uppercase_input_is_normalised_to_lowercase(self) -> None:
        # Mobile accidentally sends ``SLEEP`` / ``Sleep`` — backend
        # accepts both rather than 422-ing on a trivial casing diff.
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="SLEEP",
        )
        _, params = _list_sql_call(db)
        assert params["risk_type"] == "sleep"

    def test_whitespace_around_filter_is_trimmed(self) -> None:
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="  fall  ",
        )
        _, params = _list_sql_call(db)
        assert params["risk_type"] == "fall"


# ---------------------------------------------------------------------------
# Forward-compat: unknown values fall back to "no filter"
# ---------------------------------------------------------------------------


class TestRiskHistoryFilterForwardCompat:
    def test_unknown_value_silently_drops_to_no_filter(self) -> None:
        # A future client passing ``stress`` (not yet a real value)
        # must not 422 — silently fall back so the screen still
        # renders "All" instead of an error.
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="stress",
        )
        sql, params = _list_sql_call(db)
        assert "rs.risk_type =" not in sql
        assert "risk_type" not in params

    def test_empty_string_is_no_filter(self) -> None:
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="",
        )
        sql, params = _list_sql_call(db)
        assert "rs.risk_type =" not in sql
        assert "risk_type" not in params

    def test_explicit_none_is_no_filter(self) -> None:
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type=None,
        )
        sql, params = _list_sql_call(db)
        assert "rs.risk_type =" not in sql
        assert "risk_type" not in params

    def test_just_whitespace_is_no_filter(self) -> None:
        db = _CapturingDb()
        MonitoringService.get_risk_history(
            patient_id=7, db=db, risk_type="   ",
        )
        sql, params = _list_sql_call(db)
        assert "rs.risk_type =" not in sql
        assert "risk_type" not in params


# ---------------------------------------------------------------------------
# Date range + pagination still work alongside the filter
# ---------------------------------------------------------------------------


class TestRiskHistoryFilterCoexistsWithRangeAndPagination:
    def test_range_filter_is_still_honoured_with_risk_type(self) -> None:
        db = _CapturingDb()
        before = datetime.now(UTC)

        MonitoringService.get_risk_history(
            patient_id=7, db=db, range_key="30d", risk_type="sleep",
        )

        # The 30-day range produces a start_time roughly 30 days back.
        _, params = _list_sql_call(db)
        delta_days = (before - params["start_time"]).days
        assert 29 <= delta_days <= 30
        assert params["risk_type"] == "sleep"

    def test_pagination_params_propagate_with_risk_type(self) -> None:
        db = _CapturingDb()

        MonitoringService.get_risk_history(
            patient_id=7, db=db, page=3, limit=15, risk_type="fall",
        )

        _, params = _list_sql_call(db)
        # offset = (page - 1) * limit = (3 - 1) * 15 = 30.
        assert params["offset"] == 30
        assert params["limit"] == 15
        assert params["risk_type"] == "fall"
