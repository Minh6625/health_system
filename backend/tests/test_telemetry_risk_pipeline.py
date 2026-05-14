from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import MagicMock, Mock, patch

from fastapi import BackgroundTasks

from app.api.routes.telemetry import (
    AlertIngestRequest,
    VitalIngestItem,
    VitalIngestRequest,
    VitalIngestVitals,
    ingest_alert,
    ingest_vitals,
)
from app.models.sos_event_model import Alert, FallEvent
from app.services.risk_alert_service import RiskCalculationResult


def _build_db_for_ingest(rowcount: int = 1) -> MagicMock:
    db = MagicMock()
    db.begin_nested.return_value.__enter__.return_value = None
    db.begin_nested.return_value.__exit__.return_value = None

    insert_result = Mock()
    insert_result.rowcount = rowcount
    update_result = Mock()
    update_result.rowcount = rowcount

    db.execute.side_effect = [insert_result, update_result]
    return db


class TestTelemetryRiskPipeline:
    def test_vital_ingest_triggers_shared_risk_pipeline(self) -> None:
        db = _build_db_for_ingest()

        payload = VitalIngestRequest(
            messages=[
                VitalIngestItem(
                    db_device_id=15,
                    emitted_at=datetime(2026, 4, 16, tzinfo=UTC),
                    vitals=VitalIngestVitals(
                        heart_rate=132,
                        spo2=89,
                        temperature=38.9,
                    ),
                )
            ]
        )

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=77,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
            return_value=RiskCalculationResult(
                risk_score_id=901,
                score=92.5,
                risk_level="critical",
                model="rule_based",
                calculated_at=datetime(2026, 4, 16, tzinfo=UTC),
            ),
        ) as calculate_device_risk_mock:
            response = ingest_vitals(payload, db=db)

        assert response.ingested == 1
        assert response.errors == []
        calculate_device_risk_mock.assert_called_once_with(
            db,
            device_id=15,
            user_id=77,
            allow_cached=True,
            dispatch_alerts=True,
        )

    def test_vitals_out_of_range_alert_bridges_into_risk_alert_flow(self) -> None:
        db = MagicMock()

        payload = AlertIngestRequest(
            db_device_id=21,
            user_id=None,
            event_type="vitals_out_of_range",
            severity="high",
            timestamp=datetime(2026, 4, 16, tzinfo=UTC),
            metadata={"score": 81.0},
        )

        with patch(
            "app.api.routes.telemetry._resolve_alert_user_id",
            return_value=99,
        ), patch(
            "app.api.routes.telemetry.calculate_device_risk",
            return_value=RiskCalculationResult(
                risk_score_id=902,
                score=84.0,
                risk_level="medium",
                model="rule_based",
                calculated_at=datetime(2026, 4, 16, tzinfo=UTC),
            ),
        ) as calculate_device_risk_mock, patch(
            "app.api.routes.telemetry._is_in_post_fall_window",
            return_value=False,
        ), patch(
            "app.api.routes.telemetry.dispatch_risk_alerts",
            return_value=True,
        ) as dispatch_risk_alerts_mock:
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        assert response.ingested == 1
        assert response.errors == []
        calculate_device_risk_mock.assert_called_once_with(
            db,
            device_id=21,
            user_id=99,
            allow_cached=False,
            dispatch_alerts=False,
        )
        dispatch_risk_alerts_mock.assert_called_once_with(
            db,
            device_id=21,
            user_id=99,
            risk_level="medium",
            score=84.0,
            risk_score_id=902,
            post_fall=False,
        )
        db.add.assert_not_called()

    def test_vitals_out_of_range_critical_maps_to_risk_critical(self) -> None:
        db = MagicMock()

        payload = AlertIngestRequest(
            db_device_id=33,
            user_id=123,
            event_type="vitals_out_of_range",
            severity="critical",
            timestamp=datetime(2026, 4, 16, tzinfo=UTC),
            metadata={},
        )

        with patch(
            "app.api.routes.telemetry.calculate_device_risk",
            return_value=RiskCalculationResult(
                risk_score_id=903,
                score=97.0,
                risk_level="critical",
                model="rule_based",
                calculated_at=datetime(2026, 4, 16, tzinfo=UTC),
            ),
        ), patch(
            "app.api.routes.telemetry._is_in_post_fall_window",
            return_value=False,
        ), patch(
            "app.api.routes.telemetry.dispatch_risk_alerts",
            return_value=True,
        ) as dispatch_risk_alerts_mock:
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        assert response.ingested == 1
        assert response.errors == []
        dispatch_risk_alerts_mock.assert_called_once_with(
            db,
            device_id=33,
            user_id=123,
            risk_level="critical",
            score=97.0,
            risk_score_id=903,
            post_fall=False,
        )


class TestFallConfidenceThreshold:
    """P0 #1 — fall_detected events must clear a confidence gate before SOS escalation."""

    @staticmethod
    def _fall_payload(*, confidence: float | None) -> AlertIngestRequest:
        metadata: dict = {}
        if confidence is not None:
            metadata["confidence"] = confidence
        return AlertIngestRequest(
            db_device_id=44,
            user_id=88,
            event_type="fall_detected",
            severity="critical",
            timestamp=datetime(2026, 4, 25, tzinfo=UTC),
            metadata=metadata,
        )

    def test_high_confidence_fall_triggers_sos(self, monkeypatch) -> None:
        monkeypatch.delenv("FALL_CONFIDENCE_THRESHOLD", raising=False)
        db = MagicMock()

        # db.flush() is responsible for populating the autogenerated
        # FallEvent.id after db.add(). With a MagicMock session, flush
        # is a no-op so fall_event.id would otherwise stay as None and
        # break the post-Phase-4 int(fall_event_id) cast inside the
        # fall_critical push background task.
        def _assign_id(obj):
            if isinstance(obj, FallEvent) and obj.id is None:
                obj.id = 5001
                obj.uuid = "fall-uuid-stub"
        db.add.side_effect = _assign_id

        payload = self._fall_payload(confidence=0.92)

        with patch(
            "app.api.routes.telemetry.EmergencyService.trigger_sos",
        ) as trigger_sos, patch(
            # Post-fall risk snapshot — non-fatal but pollutes logs when
            # the real service hits a MagicMock session.
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        assert response.ingested == 2  # FallEvent + SOS dispatch
        assert response.errors == []
        trigger_sos.assert_called_once()
        kwargs = trigger_sos.call_args.kwargs
        assert kwargs["user_id"] == 88
        assert kwargs["trigger_type"] == "auto"

        added_objects = [args[0] for args, _ in db.add.call_args_list]
        # Exactly one FallEvent persisted; no soft Alert in the high-confidence path.
        assert sum(1 for obj in added_objects if isinstance(obj, FallEvent)) == 1
        assert not any(isinstance(obj, Alert) for obj in added_objects)

    def test_low_confidence_fall_creates_soft_alert_no_sos(self, monkeypatch) -> None:
        monkeypatch.delenv("FALL_CONFIDENCE_THRESHOLD", raising=False)
        db = MagicMock()
        payload = self._fall_payload(confidence=0.4)

        with patch(
            "app.api.routes.telemetry.EmergencyService.trigger_sos",
        ) as trigger_sos:
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        assert response.ingested == 2  # FallEvent + soft Alert
        assert response.errors == []
        trigger_sos.assert_not_called()

        added_objects = [args[0] for args, _ in db.add.call_args_list]
        falls = [obj for obj in added_objects if isinstance(obj, FallEvent)]
        soft_alerts = [obj for obj in added_objects if isinstance(obj, Alert)]
        assert len(falls) == 1
        assert len(soft_alerts) == 1
        soft = soft_alerts[0]
        assert soft.alert_type == "fall_detection"
        assert soft.severity == "high"
        assert soft.user_id == 88
        assert soft.details is not None
        assert soft.details["secondary_validation"] == "pending_low_confidence"
        assert soft.details["fall_confidence_threshold"] == 0.7
        assert soft.details["confidence"] == 0.4

    def test_missing_confidence_treated_as_zero_creates_soft_alert(self, monkeypatch) -> None:
        monkeypatch.delenv("FALL_CONFIDENCE_THRESHOLD", raising=False)
        db = MagicMock()
        payload = self._fall_payload(confidence=None)

        with patch(
            "app.api.routes.telemetry.EmergencyService.trigger_sos",
        ) as trigger_sos:
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        assert response.ingested == 2
        trigger_sos.assert_not_called()
        added_objects = [args[0] for args, _ in db.add.call_args_list]
        soft = next(obj for obj in added_objects if isinstance(obj, Alert))
        assert soft.severity == "high"
        assert soft.details["confidence"] == 0.0

    def test_threshold_is_overridable_via_env(self, monkeypatch) -> None:
        monkeypatch.setenv("FALL_CONFIDENCE_THRESHOLD", "0.3")
        db = MagicMock()

        # Same FallEvent.id population shim as the high-confidence test.
        def _assign_id(obj):
            if isinstance(obj, FallEvent) and obj.id is None:
                obj.id = 5002
                obj.uuid = "fall-uuid-stub2"
        db.add.side_effect = _assign_id

        payload = self._fall_payload(confidence=0.4)  # below default 0.7, above override 0.3

        with patch(
            "app.api.routes.telemetry.EmergencyService.trigger_sos",
        ) as trigger_sos, patch(
            "app.api.routes.telemetry.calculate_device_risk",
        ):
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        assert response.ingested == 2
        trigger_sos.assert_called_once()
        # No soft alert when threshold is lowered enough to escalate.
        added_objects = [args[0] for args, _ in db.add.call_args_list]
        assert not any(isinstance(obj, Alert) for obj in added_objects)

    def test_invalid_threshold_env_falls_back_to_default(self, monkeypatch) -> None:
        monkeypatch.setenv("FALL_CONFIDENCE_THRESHOLD", "not-a-number")
        db = MagicMock()
        payload = self._fall_payload(confidence=0.65)  # below default 0.7

        with patch(
            "app.api.routes.telemetry.EmergencyService.trigger_sos",
        ) as trigger_sos:
            response = ingest_alert(payload, BackgroundTasks(), db=db)

        trigger_sos.assert_not_called()
        added_objects = [args[0] for args, _ in db.add.call_args_list]
        assert any(isinstance(obj, Alert) for obj in added_objects)
