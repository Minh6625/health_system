from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import MagicMock, Mock, patch

from app.api.routes.telemetry import (
    AlertIngestRequest,
    VitalIngestItem,
    VitalIngestRequest,
    VitalIngestVitals,
    ingest_alert,
    ingest_vitals,
)
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
            allow_cached=False,
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
            "app.api.routes.telemetry.dispatch_risk_alerts",
            return_value=True,
        ) as dispatch_risk_alerts_mock:
            response = ingest_alert(payload, db=db)

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
            "app.api.routes.telemetry.dispatch_risk_alerts",
            return_value=True,
        ) as dispatch_risk_alerts_mock:
            response = ingest_alert(payload, db=db)

        assert response.ingested == 1
        assert response.errors == []
        dispatch_risk_alerts_mock.assert_called_once_with(
            db,
            device_id=33,
            user_id=123,
            risk_level="critical",
            score=97.0,
            risk_score_id=903,
        )
