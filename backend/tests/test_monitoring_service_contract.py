from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from unittest.mock import MagicMock

from app.services.monitoring_service import MonitoringService


class _FakeQueryResult:
    def __init__(self, *, first=None, all_rows=None, scalar=None):
        self._first = first
        self._all_rows = all_rows or []
        self._scalar = scalar

    def mappings(self):
        return self

    def first(self):
        return self._first

    def all(self):
        return self._all_rows

    def scalar(self):
        return self._scalar


class TestMonitoringServiceContract:
    def test_latest_vital_signs_uses_shared_five_minute_stale_threshold(self) -> None:
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.return_value = _FakeQueryResult(
            first={
                "time": now - timedelta(minutes=6),
                "heart_rate": 74.0,
                "spo2": 98.0,
                "temperature": 36.7,
                "respiratory_rate": 17.0,
                "blood_pressure_sys": 118.0,
                "blood_pressure_dia": 76.0,
            }
        )

        vitals = MonitoringService.get_latest_vital_signs(patient_id=7, db=db)

        assert MonitoringService.VITALS_STALE_AFTER == timedelta(minutes=5)
        assert vitals.is_stale is True

    def test_health_report_returns_risk_and_health_fields(self) -> None:
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(first={"heart_rate": 74.1, "spo2": 98.0}),
            _FakeQueryResult(
                first={
                    "id": 11,
                    "risk_type": "general",
                    "score": 82.0,
                    "risk_level": "high",
                    "calculated_at": now,
                    "features": {"confidence": 0.8, "backend": "onnx"},
                    "algorithm": "onnx",
                }
            ),
            _FakeQueryResult(first=None),
        ]

        report = MonitoringService.get_health_report(patient_id=7, db=db)

        assert report.latest_risk_score == 59.6
        assert report.risk_level == "medium"
        assert report.health_score == 40.4
        assert report.health_level == "watch"
        assert report.health_summary == "Sức khỏe hôm nay cần được theo dõi thêm."
        assert report.is_stale is False

    def test_health_report_refreshes_stale_risk_when_newer_vitals_exist(self, monkeypatch) -> None:
        stale_time = datetime.now(UTC) - timedelta(hours=8)
        refreshed_time = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(first={"heart_rate": 74.1, "spo2": 98.0}),
            _FakeQueryResult(
                first={
                    "id": 11,
                    "risk_type": "general",
                    "score": 82.0,
                    "risk_level": "high",
                    "calculated_at": stale_time,
                    "features": {"confidence": 0.8, "backend": "onnx"},
                    "algorithm": "onnx",
                }
            ),
            _FakeQueryResult(first={"device_id": 5, "latest_vitals_at": refreshed_time}),
            _FakeQueryResult(
                first={
                    "id": 12,
                    "risk_type": "general",
                    "score": 18.0,
                    "risk_level": "low",
                    "calculated_at": refreshed_time,
                    "features": {"confidence": 0.9, "backend": "rule_based"},
                    "algorithm": "rule_based",
                }
            ),
        ]

        refresh_calls: list[tuple[int, int, bool, bool]] = []

        def _fake_calculate_device_risk(
            db_session,
            *,
            device_id: int,
            user_id: int,
            allow_cached: bool = True,
            dispatch_alerts: bool = True,
        ):
            refresh_calls.append((device_id, user_id, allow_cached, dispatch_alerts))
            return None

        monkeypatch.setattr(
            "app.services.risk_alert_service.calculate_device_risk",
            _fake_calculate_device_risk,
        )

        report = MonitoringService.get_health_report(patient_id=7, db=db)

        assert refresh_calls == [(5, 7, False, False)]
        assert report.last_updated == refreshed_time
        assert report.is_stale is False
        assert report.risk_level == "low"

    def test_health_report_falls_back_to_latest_risk_when_refresh_raises(self, monkeypatch) -> None:
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(
                first={
                    "heart_rate": 74.1,
                    "spo2": 98.0,
                }
            ),
            _FakeQueryResult(
                first={
                    "id": 11,
                    "risk_type": "general",
                    "score": 82.0,
                    "risk_level": "high",
                    "calculated_at": now,
                    "features": {"confidence": 0.8, "backend": "onnx"},
                    "algorithm": "onnx",
                }
            ),
        ]

        monkeypatch.setattr(
            MonitoringService,
            "_refresh_latest_risk_row",
            staticmethod(lambda patient_id, db_session: (_ for _ in ()).throw(RuntimeError("boom"))),
        )

        report = MonitoringService.get_health_report(patient_id=7, db=db)

        assert report.latest_risk_score == 59.6
        assert report.health_score == 40.4
        assert report.risk_level == "medium"

    def test_health_report_returns_vitals_only_when_risk_row_missing(self, monkeypatch) -> None:
        db = MagicMock()
        db.execute.side_effect = [_FakeQueryResult(first={"heart_rate": 74.1, "spo2": 98.0})]
        monkeypatch.setattr(
            MonitoringService,
            "_refresh_latest_risk_row",
            staticmethod(lambda patient_id, db_session: None),
        )

        report = MonitoringService.get_health_report(patient_id=7, db=db)

        assert report.vitals_24h_avg == {"heart_rate": 74.1, "spo2": 98.0}
        assert report.latest_risk_score is None
        assert report.health_score is None
        assert report.risk_level is None

    def test_risk_report_detail_scopes_by_patient_id(self) -> None:
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(
                first={
                    "id": 22,
                    "user_id": 7,
                    "risk_type": "general",
                    "score": 79.0,
                    "risk_level": "critical",
                    "calculated_at": now,
                    "features": {
                        "confidence": 0.75,
                        "backend": "lightgbm",
                        "model_features": {"heart_rate": 108, "spo2": 93, "map_val": 102},
                        "raw_vitals": {
                            "heart_rate": 108,
                            "spo2": 93,
                            "blood_pressure_sys": 138,
                            "blood_pressure_dia": 84,
                            "temperature": 36.9,
                            "hrv": 28,
                        },
                    },
                    "model_version": "lightgbm-v1.0",
                    "algorithm": "lightgbm",
                    "explanation_text": "Chi so tim mach dang can theo doi sat.",
                    "feature_importance": {"heart_rate": 0.62, "spo2": 0.41},
                    "recommendations": ["Nghi ngoi va do lai.", "Theo doi SpO2 trong ngay."],
                }
            ),
            _FakeQueryResult(first=None),
            _FakeQueryResult(all_rows=[]),
        ]

        detail = MonitoringService.get_risk_report_detail(patient_id=7, report_id=22, db=db)

        assert detail is not None
        assert detail.risk_level == "critical"
        assert detail.risk_score == 91.75
        assert detail.health_score == 8.25
        assert detail.snapshot.heart_rate == 108
        assert len(detail.breakdown) == 2
        sql_params = db.execute.call_args_list[0].args[1]
        assert sql_params["user_id"] == 7
        assert sql_params["report_id"] == 22

    def test_risk_history_returns_screen_ready_shape(self) -> None:
        now = datetime.now(UTC)
        current_row = {
            "calculated_at": now - timedelta(days=1),
            "score": 75,
            "risk_level": "critical",
            "algorithm": "rule_based",
            "features": {"confidence": 0.9},
        }
        previous_row = {
            "calculated_at": now - timedelta(days=10),
            "score": 44,
            "risk_level": "medium",
            "algorithm": "rule_based",
            "features": {"confidence": 0.6},
        }
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(scalar=3),
            _FakeQueryResult(
                all_rows=[
                    {
                        "id": 101,
                        "risk_type": "general",
                        "score": 75,
                        "risk_level": "critical",
                        "calculated_at": now - timedelta(days=1),
                        "features": {"confidence": 0.9, "backend": "rule_based"},
                        "algorithm": "rule_based",
                        "explanation_text": "Chi so canh bao dang tang.",
                    }
                ]
            ),
            _FakeQueryResult(all_rows=[current_row]),
            _FakeQueryResult(all_rows=[previous_row]),
        ]

        history = MonitoringService.get_risk_history(
            patient_id=9,
            db=db,
            range_key="7d",
            page=1,
            limit=1,
        )

        assert history.range == "7d"
        assert history.page == 1
        assert history.limit == 1
        assert history.has_more is True
        assert len(history.items) == 1
        assert history.items[0].risk_level == "critical"
        assert history.items[0].display_status == "Nguy hiểm"
        assert history.summary.highest_score == 75.0

    def test_risk_reports_keep_null_previous_score_for_first_report(self, monkeypatch) -> None:
        now = datetime.now(UTC)
        db = MagicMock()
        db.execute.return_value = _FakeQueryResult(
            all_rows=[
                {
                    "id": 101,
                    "risk_type": "general",
                    "score": 18,
                    "risk_level": "low",
                    "calculated_at": now,
                    "features": {"confidence": 0.9, "backend": "rule_based"},
                    "algorithm": "rule_based",
                    "explanation_text": "On dinh.",
                    "feature_importance": {"heart_rate": 0.18},
                    "recommendations": ["Tiep tuc theo doi."],
                }
            ]
        )

        monkeypatch.setattr(
            MonitoringService,
            "_previous_risk_score",
            staticmethod(lambda patient_id, risk_type, current_timestamp, db_session: None),
        )
        monkeypatch.setattr(
            MonitoringService,
            "_compute_trend_7d",
            staticmethod(lambda patient_id, risk_type, current_timestamp, db_session: [24, 21, 18]),
        )

        reports = MonitoringService.get_risk_reports(patient_id=7, db=db, limit=1)

        assert len(reports) == 1
        assert reports[0].previous_score is None

    def test_sleep_latest_and_history_share_canonical_builder(self) -> None:
        report_day = date(2026, 4, 16)
        start_time = datetime(2026, 4, 15, 22, 30, tzinfo=UTC)
        end_time = datetime(2026, 4, 16, 5, 30, tzinfo=UTC)
        row = {
            "start_time": start_time,
            "end_time": end_time,
            "sleep_score": 68,
            "wake_count": 2,
            "phases": {"light": 220, "deep": 90, "rem": 70, "awake": 40},
            "sleep_date": report_day,
        }
        db = MagicMock()
        db.execute.side_effect = [
            _FakeQueryResult(first=row),
            _FakeQueryResult(all_rows=[row]),
        ]

        latest = MonitoringService.get_latest_sleep_session(patient_id=7, db=db)
        history = MonitoringService.get_sleep_history(
            patient_id=7,
            db=db,
            from_date=report_day.isoformat(),
            to_date=report_day.isoformat(),
        )

        assert latest is not None
        assert len(history) == 1
        assert latest.model_dump() == history[0].model_dump()
        assert latest.sleep_date == report_day
        assert latest.quality_label == "AVERAGE"
        assert latest.sleep_minutes == 380
        assert latest.awake_minutes == 40
        assert latest.wake_count == 2
        assert latest.phases == {"light": 220, "deep": 90, "rem": 70, "awake": 40}

    def test_sleep_builder_keeps_sleep_date_and_quality_thresholds(self) -> None:
        start_time = datetime(2026, 4, 15, 22, 0, tzinfo=UTC)
        end_time = datetime(2026, 4, 16, 5, 0, tzinfo=UTC)

        good = MonitoringService._build_sleep_session_response(
            {
                "start_time": start_time,
                "end_time": end_time,
                "sleep_score": 70,
                "wake_count": 1,
                "phases": {"light": 210, "deep": 90, "rem": 60, "awake": 60},
                "sleep_date": "2026-04-15",
            }
        )
        average = MonitoringService._build_sleep_session_response(
            {
                "start_time": start_time,
                "end_time": end_time,
                "sleep_score": 50,
                "wake_count": 1,
                "phases": {"light": 210, "deep": 90, "rem": 60, "awake": 60},
                "sleep_date": "2026-04-15",
            }
        )
        poor = MonitoringService._build_sleep_session_response(
            {
                "start_time": start_time,
                "end_time": end_time,
                "sleep_score": 49,
                "wake_count": 1,
                "phases": {"light": 210, "deep": 90, "rem": 60, "awake": 60},
                "sleep_date": None,
            }
        )

        assert good.sleep_date == date(2026, 4, 15)
        assert good.quality_label == "GOOD"
        assert average.quality_label == "AVERAGE"
        assert poor.sleep_date == end_time.date()
        assert poor.quality_label == "POOR"

    def test_sleep_history_filters_with_sleep_date_params_not_timestamp_windows(self) -> None:
        db = MagicMock()
        db.execute.side_effect = [_FakeQueryResult(all_rows=[])]

        history = MonitoringService.get_sleep_history(
            patient_id=9,
            db=db,
            from_date="2026-04-14",
            to_date="2026-04-16",
            limit=10,
        )

        assert history == []
        sql_params = db.execute.call_args.args[1]
        assert sql_params["user_id"] == 9
        assert sql_params["from_date"] == date(2026, 4, 14)
        assert sql_params["to_date"] == date(2026, 4, 16)
        assert sql_params["limit"] == 10

    # ------------------------------------------------------------------
    # F-12 (M-6): vitals time-series endpoint contract.
    #
    # Pre-fix the mobile chart on `vital_detail_screen.dart` showed the
    # empty placeholder forever because `VitalSignsProvider.chartData`
    # returned `const []` and no endpoint produced time-series data.
    # These tests pin the new `MonitoringService.get_vitals_timeseries`
    # contract: range coercion for unsupported tab values, the SQL
    # parameter shape (so a future refactor can't accidentally drop the
    # device join), the empty-vs-missing-table semantics, and the per
    # channel null-passthrough that lets the mobile chart draw gaps
    # instead of zero floors when a sensor stops streaming.
    # ------------------------------------------------------------------

    def test_vitals_timeseries_returns_empty_envelope_when_table_missing(self) -> None:
        from sqlalchemy.exc import ProgrammingError

        db = MagicMock()
        db.execute.side_effect = ProgrammingError(
            statement="SELECT 1",
            params={},
            orig=Exception('relation "vitals" does not exist'),
        )

        result = MonitoringService.get_vitals_timeseries(patient_id=42, db=db)

        # Service swallows the missing-table error and returns the same
        # 200 + empty envelope shape used elsewhere (cf. sleep_history).
        # 500-ing here would force the mobile chart to render an error
        # toast on a fresh DB, which is what M-6 was about avoiding.
        assert result.range == "24h"
        assert result.bucket_minutes == 15
        assert result.data == []
        # Caller must rollback so the session can be reused — without
        # this the next query in the same request would 500.
        db.rollback.assert_called_once()

    def test_vitals_timeseries_coerces_unknown_range_to_24h(self) -> None:
        db = MagicMock()
        db.execute.return_value = _FakeQueryResult(all_rows=[])

        result = MonitoringService.get_vitals_timeseries(
            patient_id=7, db=db, range_key="bogus"
        )

        # An unknown range MUST silently fall back to "24h" rather than
        # 400-ing. Future range tabs will land progressively, and an
        # older mobile build sending a not-yet-supported value should
        # still get a sensible chart instead of a hard error.
        assert result.range == "24h"
        assert result.bucket_minutes == 15

    def test_vitals_timeseries_passes_user_id_and_interval_strings_to_sql(self) -> None:
        db = MagicMock()
        db.execute.return_value = _FakeQueryResult(all_rows=[])

        MonitoringService.get_vitals_timeseries(patient_id=11, db=db, range_key="24h")

        # Verify the SQL parameter dict, not the rendered SQL: the row
        # must be filtered by the patient (via the device join) and the
        # bucket / window intervals must be passed as strings castable to
        # Postgres `interval` so a refactor that breaks one of these
        # silently is caught here instead of at runtime in production.
        call_kwargs = db.execute.call_args.args[1]
        assert call_kwargs["user_id"] == 11
        assert call_kwargs["bucket_interval"] == "15 minutes"
        assert call_kwargs["window_interval"] == "24 hours"

    def test_vitals_timeseries_maps_rows_into_points_preserving_nulls(self) -> None:
        bucket_a = datetime(2026, 4, 29, 6, 0, tzinfo=UTC)
        bucket_b = datetime(2026, 4, 29, 6, 15, tzinfo=UTC)
        db = MagicMock()
        # Row B has spo2=None on purpose — when the sensor drops out
        # mid-bucket the chart needs a null in that channel so the line
        # draws a gap instead of crashing through to zero.
        db.execute.return_value = _FakeQueryResult(
            all_rows=[
                {
                    "bucket_ts": bucket_a,
                    "heart_rate": 72.0,
                    "spo2": 98.0,
                    "temperature": 36.7,
                    "respiratory_rate": 16.0,
                    "blood_pressure_sys": 118.0,
                    "blood_pressure_dia": 76.0,
                },
                {
                    "bucket_ts": bucket_b,
                    "heart_rate": 74.5,
                    "spo2": None,
                    "temperature": 36.8,
                    "respiratory_rate": 17.0,
                    "blood_pressure_sys": None,
                    "blood_pressure_dia": None,
                },
            ]
        )

        result = MonitoringService.get_vitals_timeseries(patient_id=3, db=db)

        assert len(result.data) == 2
        assert result.data[0].ts == bucket_a
        assert result.data[0].heart_rate == 72.0
        assert result.data[0].spo2 == 98.0
        assert result.data[1].ts == bucket_b
        assert result.data[1].heart_rate == 74.5
        # Channel-level null MUST round-trip as None, not 0.0, so the
        # mobile chart can draw a gap; a zero would render a misleading
        # "SpO2 dropped to 0" cliff in the line.
        assert result.data[1].spo2 is None
        assert result.data[1].blood_pressure_sys is None
        assert result.data[1].blood_pressure_dia is None

    def test_vitals_timeseries_7d_range_uses_hourly_buckets(self) -> None:
        db = MagicMock()
        db.execute.return_value = _FakeQueryResult(all_rows=[])

        result = MonitoringService.get_vitals_timeseries(
            patient_id=4, db=db, range_key="7d"
        )

        # Pin the bucket sizing so a future refactor can't silently
        # change the payload shape and break the mobile X-axis labels.
        assert result.range == "7d"
        assert result.bucket_minutes == 60
        call_kwargs = db.execute.call_args.args[1]
        assert call_kwargs["bucket_interval"] == "60 minutes"
        assert call_kwargs["window_interval"] == "168 hours"
