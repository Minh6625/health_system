"""Phase 7 — audience-payload cache contract tests.

Pins the lazy write-through cache behaviour on
``MonitoringService.get_risk_report_detail`` /
``get_risk_report_clinician_detail``:

1. **Miss → build → write-through.** First read on a row with
   ``audience_payload_json IS NULL`` builds the DTO via the existing
   assembly path and writes it to the cache column.
2. **Hit (current version).** Second read with a matching cache entry
   short-circuits the builder entirely.
3. **Stale version.** A cached entry whose ``contract_version`` does
   not equal :data:`RISK_CONTRACT_VERSION` is treated as a miss; the
   row is rebuilt and the entry is overwritten.
4. **Partial dict append.** A row with ``patient`` cached but
   ``clinician`` not cached → clinician request rebuilds + merges into
   the existing dict (does not erase the patient entry).
5. **Write failure tolerance.** A failed cache UPDATE never propagates
   into the request flow — the freshly-built DTO is still returned.
6. **Timing tags.** ``record_timing`` is called with ``cache="hit"``
   on hits and ``cache="miss"`` on misses, with a non-empty ``reason``
   tag on every miss for observability.

The tests fake the DB Session via the same ``_FakeQueryResult`` pattern
used in ``test_monitoring_service_contract.py``. Builder calls are
replaced with hard-coded DTO factories so the tests focus on cache
behaviour, not on the (separately tested) builder logic.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from unittest.mock import MagicMock

import pytest

from app.core.risk_contract import RISK_CONTRACT_VERSION
from app.schemas.monitoring import (
    RiskReportClinicianResponse,
    RiskReportDetailResponse,
    SnapshotMetricsResponse,
)
from app.services.monitoring_service import MonitoringService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


class _FakeQueryResult:
    def __init__(self, *, first=None):
        self._first = first

    def mappings(self):
        return self

    def first(self):
        return self._first


_TIMESTAMP = datetime(2026, 4, 27, 10, 0, tzinfo=UTC)


def _fixed_patient_dto() -> RiskReportDetailResponse:
    return RiskReportDetailResponse(
        id=42,
        risk_type="general",
        risk_score=18.0,
        score=18.0,
        health_score=82.0,
        risk_level="low",
        health_level="good",
        display_status="Ổn định",
        summary="OK",
        timestamp=_TIMESTAMP,
        previous_score=None,
        trend_7d=[24, 21, 19, 18],
        explanation="",
        xai_explanation="",
        features={},
        feature_importance={},
        breakdown=[],
        recommendations=[],
        recommendation_preview=[],
        top_factors=[],
        snapshot=SnapshotMetricsResponse(),
        model_version="1.0",
        algorithm="rule_based",
        confidence=0.92,
        is_stale=False,
        ai_explanation=None,
    )


def _fixed_clinician_dto() -> RiskReportClinicianResponse:
    base = _fixed_patient_dto().model_dump()
    return RiskReportClinicianResponse(
        **base,
        shap_details={"available": True, "base_value": 0.05, "values": []},
        model_request_id="rq01-9b3d-2a9c-4d27-9e1a-1234abcd",
    )


def _row(
    *,
    audience_payload_json: dict[str, Any] | None = None,
    risk_explanation_id: int | None = 99,
) -> dict[str, Any]:
    """Construct a fake LATERAL-join row with the columns the cache logic reads.

    The detail builders also read a much wider set of columns, but those
    are consumed by ``_build_detail_inputs`` which is stubbed out in
    every test, so they do not need to be present here.
    """
    return {
        "id": 42,
        "user_id": 7,
        "risk_type": "general",
        "score": 18.0,
        "risk_level": "low",
        "calculated_at": _TIMESTAMP,
        "features": {"confidence": 0.92},
        "model_version": "1.0",
        "algorithm": "rule_based",
        "risk_explanation_id": risk_explanation_id,
        "explanation_text": "",
        "feature_importance": {},
        "recommendations": [],
        "top_features_json": [],
        "ai_explanation_json": None,
        "shap_details_json": None,
        "model_request_id": None,
        "audience_payload_json": audience_payload_json,
    }


@pytest.fixture
def patch_builders(monkeypatch: pytest.MonkeyPatch):
    """Replace ``_build_detail_inputs`` + the two builders with simple stubs.

    Returns a dict of call-count counters so tests can assert that the
    builder did or did not run.
    """
    counters = {"patient_builder": 0, "clinician_builder": 0, "build_inputs": 0}

    def _stub_inputs(patient_id, row_dict, db):  # noqa: ARG001
        counters["build_inputs"] += 1
        return {}  # ignored by stubbed builders

    def _stub_patient_builder(**kwargs):  # noqa: ARG001
        counters["patient_builder"] += 1
        return _fixed_patient_dto()

    def _stub_clinician_builder(**kwargs):  # noqa: ARG001
        counters["clinician_builder"] += 1
        return _fixed_clinician_dto()

    monkeypatch.setattr(
        MonitoringService,
        "_build_detail_inputs",
        staticmethod(_stub_inputs),
    )
    monkeypatch.setattr(
        "app.services.monitoring_service.build_risk_report_detail",
        _stub_patient_builder,
    )
    monkeypatch.setattr(
        "app.services.monitoring_service.build_risk_report_clinician_detail",
        _stub_clinician_builder,
    )
    return counters


@pytest.fixture
def capture_timings(monkeypatch: pytest.MonkeyPatch):
    """Capture every ``record_timing`` call so tests can assert tag shapes."""
    captured: list[tuple[str, float, dict[str, Any]]] = []

    def _stub(stage: str, duration_ms: float, **tags):
        captured.append((stage, duration_ms, tags))

    monkeypatch.setattr(
        "app.services.monitoring_service.record_timing",
        _stub,
    )
    return captured


# ---------------------------------------------------------------------------
# Cache miss → build → write-through
# ---------------------------------------------------------------------------


class TestCacheMissBuildAndWrite:
    def test_first_read_on_uncached_row_builds_and_writes(
        self, patch_builders, capture_timings
    ) -> None:
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(first=_row(audience_payload_json=None)),
            None,  # the UPDATE call returns nothing meaningful
        ]

        result = MonitoringService.get_risk_report_detail(
            patient_id=7, report_id=42, db=db,
        )

        assert isinstance(result, RiskReportDetailResponse)
        assert patch_builders["patient_builder"] == 1
        assert patch_builders["build_inputs"] == 1

        # Second db.execute call must be the cache UPDATE.
        update_call = db.execute.call_args_list[1]
        update_sql = str(update_call.args[0])
        assert "UPDATE risk_explanations" in update_sql
        assert "audience_payload_json" in update_sql
        assert update_call.args[1]["risk_explanation_id"] == 99

        # Timing tags: one cache="miss" with reason="no_cache_column".
        miss_tags = [tags for (_, _, tags) in capture_timings if tags.get("cache") == "miss"]
        assert len(miss_tags) == 1
        assert miss_tags[0]["audience"] == "patient"
        assert miss_tags[0]["reason"] == "no_cache_column"


# ---------------------------------------------------------------------------
# Cache hit (current version) → skip builder
# ---------------------------------------------------------------------------


class TestCacheHit:
    def test_matching_version_returns_cached_payload(
        self, patch_builders, capture_timings
    ) -> None:
        cached_payload = _fixed_patient_dto().model_dump(mode="json")
        db = MagicMock()
        db.execute.return_value = _FakeQueryResult(
            first=_row(
                audience_payload_json={
                    "patient": {
                        "contract_version": RISK_CONTRACT_VERSION,
                        "payload": cached_payload,
                    }
                }
            )
        )

        result = MonitoringService.get_risk_report_detail(
            patient_id=7, report_id=42, db=db,
        )

        assert isinstance(result, RiskReportDetailResponse)
        assert result.id == 42
        # The builder MUST NOT have run on a cache hit.
        assert patch_builders["patient_builder"] == 0
        assert patch_builders["build_inputs"] == 0
        # No UPDATE issued — only the initial SELECT.
        assert db.execute.call_count == 1
        # Timing tag: exactly one cache="hit", audience="patient".
        hit_tags = [tags for (_, _, tags) in capture_timings if tags.get("cache") == "hit"]
        assert len(hit_tags) == 1
        assert hit_tags[0]["audience"] == "patient"


# ---------------------------------------------------------------------------
# Stale contract version → invalidate + rebuild
# ---------------------------------------------------------------------------


class TestVersionInvalidation:
    def test_stale_version_treated_as_miss_and_overwritten(
        self, patch_builders, capture_timings
    ) -> None:
        stale_payload = {"id": 999, "old_field": "ignored"}
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(
                first=_row(
                    audience_payload_json={
                        "patient": {
                            "contract_version": "0.0.1-stale",
                            "payload": stale_payload,
                        }
                    }
                )
            ),
            None,  # the rebuild's UPDATE
        ]

        result = MonitoringService.get_risk_report_detail(
            patient_id=7, report_id=42, db=db,
        )

        assert isinstance(result, RiskReportDetailResponse)
        # Builder ran (rebuild path) — so the stale payload's ``id=999`` is gone.
        assert result.id == 42
        assert patch_builders["patient_builder"] == 1
        # Miss tag must carry reason=version_mismatch for observability.
        miss_tags = [tags for (_, _, tags) in capture_timings if tags.get("cache") == "miss"]
        assert miss_tags == [
            {"audience": "patient", "cache": "miss", "reason": "version_mismatch"}
        ]


# ---------------------------------------------------------------------------
# Partial dict — patient cached, clinician missing → merge on write
# ---------------------------------------------------------------------------


class TestPartialCacheAppend:
    def test_clinician_request_merges_into_existing_patient_entry(
        self, patch_builders, capture_timings,
    ) -> None:
        patient_payload = _fixed_patient_dto().model_dump(mode="json")
        existing_cache = {
            "patient": {
                "contract_version": RISK_CONTRACT_VERSION,
                "payload": patient_payload,
            }
        }
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(first=_row(audience_payload_json=existing_cache)),
            None,  # cache UPDATE
        ]

        result = MonitoringService.get_risk_report_clinician_detail(
            patient_id=7, report_id=42, db=db,
        )

        assert isinstance(result, RiskReportClinicianResponse)
        assert patch_builders["clinician_builder"] == 1
        # The UPDATE param must include BOTH patient and clinician keys
        # (i.e. patient was preserved, not overwritten).
        update_params = db.execute.call_args_list[1].args[1]
        import json as _json
        cache_arg = _json.loads(update_params["cache"])
        assert set(cache_arg.keys()) == {"patient", "clinician"}
        assert cache_arg["patient"]["payload"] == patient_payload
        assert cache_arg["clinician"]["contract_version"] == RISK_CONTRACT_VERSION

        # Miss reason on the clinician side: no_audience_entry.
        miss_tags = [tags for (_, _, tags) in capture_timings if tags.get("cache") == "miss"]
        assert miss_tags == [
            {"audience": "clinician", "cache": "miss", "reason": "no_audience_entry"}
        ]


# ---------------------------------------------------------------------------
# Write failure must not break the request flow
# ---------------------------------------------------------------------------


class TestWriteFailureTolerance:
    def test_failed_cache_update_still_returns_built_dto(
        self, patch_builders, capture_timings,
    ) -> None:
        db = MagicMock()

        def _execute(stmt, params=None):
            sql = str(stmt)
            if "UPDATE risk_explanations" in sql:
                raise RuntimeError("simulated DB outage on UPDATE")
            return _FakeQueryResult(first=_row(audience_payload_json=None))

        db.execute.side_effect = _execute

        # Must not raise — cache write is best-effort.
        result = MonitoringService.get_risk_report_detail(
            patient_id=7, report_id=42, db=db,
        )

        assert isinstance(result, RiskReportDetailResponse)
        assert patch_builders["patient_builder"] == 1
        # And the rollback was called so the session stays usable.
        db.rollback.assert_called_once()


# ---------------------------------------------------------------------------
# Timing tags must always be emitted with audience + cache labels
# ---------------------------------------------------------------------------


class TestTimingObservability:
    def test_every_outcome_emits_a_build_dto_timing_record(
        self, patch_builders, capture_timings,
    ) -> None:
        # One miss path + one hit path on the same audience.
        cached_payload = _fixed_patient_dto().model_dump(mode="json")

        db1 = MagicMock()
        db1.execute.side_effect = [
            _FakeQueryResult(first=_row(audience_payload_json=None)),
            None,
        ]
        MonitoringService.get_risk_report_detail(
            patient_id=7, report_id=42, db=db1,
        )

        db2 = MagicMock()
        db2.execute.return_value = _FakeQueryResult(
            first=_row(
                audience_payload_json={
                    "patient": {
                        "contract_version": RISK_CONTRACT_VERSION,
                        "payload": cached_payload,
                    }
                }
            )
        )
        MonitoringService.get_risk_report_detail(
            patient_id=7, report_id=42, db=db2,
        )

        # Two ``build_dto`` records: one miss, one hit, both audience=patient.
        build_dto_records = [
            (stage, tags) for (stage, _, tags) in capture_timings if stage == "build_dto"
        ]
        assert len(build_dto_records) == 2
        outcomes = [tags["cache"] for (_, tags) in build_dto_records]
        assert outcomes == ["miss", "hit"]
        for _, tags in build_dto_records:
            assert tags["audience"] == "patient"
