from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
import json
import logging
from typing import Any

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.core.risk_contract import RISK_CONTRACT_VERSION
from app.observability.timing import record_timing
from app.schemas.monitoring import (
    AiExplanationResponse,
    FactorBreakdownResponse,
    HealthReportResponse,
    RiskHistoryItemResponse,
    RiskHistoryResponse,
    RiskHistorySummaryResponse,
    RiskReportClinicianResponse,
    RiskReportDetailResponse,
    RiskReportResponse,
    SleepSessionResponse,
    SnapshotMetricsResponse,
    TopFactorResponse,
    VitalSignsResponse,
    VitalsTimeseriesPointResponse,
    VitalsTimeseriesResponse,
)
from app.services.normalized_risk_row import NormalizedRiskRow
from app.services.risk_inference_service import (
    canonicalize_risk_level,
    derive_display_status,
    derive_health_level,
    derive_health_score,
    derive_health_summary,
    derive_risk_summary,
    is_risk_report_stale,
    normalize_risk_score,
)
from app.services.risk_report_builder import (
    build_risk_history_item,
    build_risk_report,
    build_risk_report_clinician_detail,
    build_risk_report_detail,
)

logger = logging.getLogger(__name__)


class MonitoringService:
    """Fetch mobile monitoring data using canonical risk/health semantics."""

    VITALS_STALE_AFTER = timedelta(minutes=5)
    RISK_HISTORY_RANGE_DAYS = {
        "7d": 7,
        "30d": 30,
        "90d": 90,
    }
    _FEATURE_META: dict[str, dict[str, str]] = {
        "heart_rate": {"label": "Nhịp tim", "unit": "bpm", "route_target": "vital_hr"},
        "spo2": {"label": "SpO2", "unit": "%", "route_target": "vital_spo2"},
        "sys_bp": {"label": "Huyết áp tâm thu", "unit": "mmHg", "route_target": "vital_bp"},
        "dia_bp": {"label": "Huyết áp tâm trương", "unit": "mmHg", "route_target": "vital_bp"},
        "resp_rate": {"label": "Nhịp thở", "unit": "lần/phút", "route_target": "vital_rr"},
        "body_temp": {"label": "Nhiệt độ", "unit": "độ C", "route_target": "vital_temp"},
        "hrv": {"label": "Biến thiên nhịp tim", "unit": "ms", "route_target": "vital_hrv"},
        "map_val": {"label": "Huyết áp trung bình", "unit": "mmHg", "route_target": "vital_bp"},
        "bmi": {"label": "BMI", "unit": "kg/m2", "route_target": "vital_bmi"},
    }

    @staticmethod
    def _safe_float(value: Any, default: float = 0.0) -> float:
        if value is None:
            return default
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _safe_int(value: Any, default: int = 0) -> int:
        if value is None:
            return default
        try:
            return int(round(float(value)))
        except (TypeError, ValueError):
            return default

    @staticmethod
    def _parse_json_object(value: Any) -> dict[str, Any]:
        if isinstance(value, dict):
            return value
        if isinstance(value, str):
            try:
                parsed = json.loads(value)
                if isinstance(parsed, dict):
                    return parsed
            except json.JSONDecodeError:
                return {}
        return {}

    @staticmethod
    def _parse_json_list(value: Any) -> list[Any]:
        if isinstance(value, list):
            return value
        if isinstance(value, str):
            try:
                parsed = json.loads(value)
                if isinstance(parsed, list):
                    return parsed
            except json.JSONDecodeError:
                return []
        return []

    @staticmethod
    def _calculate_sleep_metrics(
        phases: dict[str, int],
        quality_score: int,
        in_bed_minutes: int,
    ) -> tuple[int, int, float, str]:
        sleep_minutes = phases.get("light", 0) + phases.get("deep", 0) + phases.get("rem", 0)
        awake_minutes = phases.get("awake", 0)
        efficiency_ratio = sleep_minutes / in_bed_minutes if in_bed_minutes > 0 else 0.0

        if quality_score >= 70:
            quality_label = "GOOD"
        elif quality_score >= 50:
            quality_label = "AVERAGE"
        else:
            quality_label = "POOR"

        return sleep_minutes, awake_minutes, efficiency_ratio, quality_label

    @staticmethod
    def _normalize_sleep_date(value: str | date | datetime | None) -> date | None:
        if value is None:
            return None
        if isinstance(value, date) and not isinstance(value, datetime):
            return value
        if isinstance(value, datetime):
            return value.date()
        try:
            return date.fromisoformat(str(value))
        except ValueError:
            return None

    @staticmethod
    def _build_sleep_session_response(row: dict[str, Any]) -> SleepSessionResponse:
        phases = {"awake": 0, "light": 0, "deep": 0, "rem": 0}
        parsed_phases = MonitoringService._parse_json_object(row.get("phases"))
        for key, value in parsed_phases.items():
            phases[key] = MonitoringService._safe_int(value)

        start_time = row["start_time"]
        end_time = row["end_time"]
        in_bed_minutes = max(0, int((end_time - start_time).total_seconds() // 60))
        quality_score = MonitoringService._safe_int(row.get("sleep_score"))
        sleep_minutes, awake_minutes, efficiency_ratio, quality_label = (
            MonitoringService._calculate_sleep_metrics(phases, quality_score, in_bed_minutes)
        )
        sleep_date = MonitoringService._normalize_sleep_date(row.get("sleep_date")) or end_time.date()

        return SleepSessionResponse(
            session_id=str(start_time.timestamp()),
            sleep_date=sleep_date,
            quality_score=quality_score,
            quality_label=quality_label,
            in_bed_minutes=in_bed_minutes,
            sleep_minutes=sleep_minutes,
            awake_minutes=awake_minutes,
            efficiency_ratio=efficiency_ratio,
            wake_count=MonitoringService._safe_int(row.get("wake_count")),
            phases=phases,
            start_time=start_time,
            end_time=end_time,
        )

    @staticmethod
    def _normalize_risk_row(row: dict[str, Any]) -> NormalizedRiskRow:
        """Project a raw ``risk_scores`` row into the canonical normalized form.

        Phase 3: returns the typed :class:`NormalizedRiskRow` dataclass
        instead of the legacy ``dict[str, Any]``. The set of produced fields
        is now explicit; consumers use attribute access.
        """
        features = MonitoringService._parse_json_object(row.get("features"))
        backend = row.get("algorithm") or features.get("backend") or "unknown"
        confidence = MonitoringService._safe_float(features.get("confidence"), 0.0)
        risk_level = canonicalize_risk_level(
            row.get("risk_level") or features.get("risk_level") or features.get("label")
        ) or "medium"
        risk_score = normalize_risk_score(
            level=risk_level,
            confidence=confidence,
            raw_score=row.get("score"),
            backend=backend,
        )
        health_score = derive_health_score(risk_score)
        timestamp = row.get("calculated_at")
        feature_snapshot = MonitoringService._parse_json_object(features.get("model_features"))
        raw_vitals = MonitoringService._parse_json_object(features.get("raw_vitals"))
        feature_importance = MonitoringService._parse_json_object(row.get("feature_importance"))
        recommendations = MonitoringService._parse_json_list(row.get("recommendations"))
        top_features = MonitoringService._parse_json_list(row.get("top_features_json"))
        ai_explanation = MonitoringService._parse_json_object(row.get("ai_explanation_json"))
        explanation_text = row.get("explanation_text")
        model_version = row.get("model_version")
        algorithm = row.get("algorithm")
        # Phase 5: surface the persisted shap waterfall + upstream request id
        # on the read path. ``shap_details_json`` is a JSONB so it arrives
        # already-parsed as a dict (or None for legacy rows). ``model_request_id``
        # is a varchar; defensively coerce + truncate in case the DB ever
        # gets a value that exceeds the column width via a future migration.
        raw_shap = row.get("shap_details_json")
        shap_details = raw_shap if isinstance(raw_shap, dict) else None
        raw_request_id = row.get("model_request_id")
        model_request_id: str | None = None
        if raw_request_id is not None:
            candidate = str(raw_request_id).strip()
            model_request_id = candidate[:36] if candidate else None
        return NormalizedRiskRow(
            # Some intermediate query paths (e.g. ``_get_history_summary``)
            # only need timestamp + risk_score and pass rows that omit
            # ``id``. Default to 0 so the dataclass accepts them; downstream
            # consumers that depend on ``id`` already receive proper rows
            # from the LATERAL-joined queries.
            id=int(row["id"]) if "id" in row else 0,
            risk_type=str(row.get("risk_type") or ""),
            risk_score=risk_score,
            health_score=health_score,
            risk_level=risk_level,
            health_level=derive_health_level(risk_level),
            display_status=derive_display_status(risk_level),
            risk_summary=derive_risk_summary(risk_level),
            health_summary=derive_health_summary(risk_level),
            timestamp=timestamp,
            confidence=round(confidence, 4),
            is_stale=is_risk_report_stale(timestamp),
            features=features,
            feature_snapshot=feature_snapshot,
            raw_vitals=raw_vitals,
            feature_importance=feature_importance,
            top_features=[item for item in top_features if isinstance(item, dict)],
            ai_explanation=ai_explanation,
            recommendations=[str(item) for item in recommendations if str(item).strip()],
            explanation_text=str(explanation_text) if explanation_text is not None else None,
            model_version=str(model_version) if model_version is not None else None,
            algorithm=str(algorithm) if algorithm is not None else None,
            shap_details=shap_details,
            model_request_id=model_request_id,
        )

    @staticmethod
    def _top_factors(
        feature_importance: dict[str, Any],
        limit: int = 2,
        top_features: list[dict[str, Any]] | None = None,
    ) -> list[TopFactorResponse]:
        # Prefer structured SHAP top_features from model-api when available.
        if top_features:
            top_items: list[TopFactorResponse] = []
            for entry in top_features[:limit]:
                if not isinstance(entry, dict):
                    continue
                key = str(entry.get("feature") or entry.get("key") or "")
                if not key:
                    continue
                meta = MonitoringService._FEATURE_META.get(
                    key,
                    {"label": key.replace("_", " ").title(), "unit": "", "route_target": ""},
                )
                top_items.append(
                    TopFactorResponse(
                        key=key,
                        label=meta["label"],
                        impact=round(MonitoringService._safe_float(entry.get("impact")), 4),
                        direction=str(entry.get("direction") or ""),
                        reason=str(entry.get("reason") or ""),
                        feature_value=MonitoringService._format_metric_value(
                            entry.get("feature_value")
                        ),
                    )
                )
            if top_items:
                return top_items

        # Fallback: legacy feature_importance map (no direction / reason).
        items = sorted(
            ((key, MonitoringService._safe_float(value)) for key, value in feature_importance.items()),
            key=lambda item: item[1],
            reverse=True,
        )
        legacy_items: list[TopFactorResponse] = []
        for key, _score in items[:limit]:
            meta = MonitoringService._FEATURE_META.get(
                key,
                {"label": key.replace("_", " ").title(), "unit": "", "route_target": ""},
            )
            legacy_items.append(TopFactorResponse(key=key, label=meta["label"]))
        return legacy_items

    @staticmethod
    def _format_metric_value(value: Any) -> str:
        if value is None:
            return "--"
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            return str(value)
        if abs(numeric - round(numeric)) < 0.01:
            return str(int(round(numeric)))
        return f"{numeric:.1f}"

    @staticmethod
    def _index_top_features(
        top_features: list[dict[str, Any]] | None,
    ) -> dict[str, dict[str, Any]]:
        """Index model-api top_features by canonical feature key for quick lookup."""
        if not top_features:
            return {}
        indexed: dict[str, dict[str, Any]] = {}
        for entry in top_features:
            if not isinstance(entry, dict):
                continue
            key = str(entry.get("feature") or entry.get("key") or "")
            if key:
                indexed[key] = entry
        return indexed

    @staticmethod
    def _build_breakdown(
        feature_importance: dict[str, Any],
        feature_snapshot: dict[str, Any],
        raw_vitals: dict[str, Any],
        top_features: list[dict[str, Any]] | None = None,
    ) -> list[FactorBreakdownResponse]:
        top_features_index = MonitoringService._index_top_features(top_features)

        # Merge keys: prefer SHAP top_features; fall back to legacy feature_importance.
        merged_scores: dict[str, float] = {}
        for key, value in feature_importance.items():
            merged_scores[key] = MonitoringService._safe_float(value)
        for key, entry in top_features_index.items():
            merged_scores[key] = MonitoringService._safe_float(
                entry.get("impact"), merged_scores.get(key, 0.0)
            )

        breakdown: list[FactorBreakdownResponse] = []
        for key, contribution_raw in sorted(
            merged_scores.items(),
            key=lambda item: item[1],
            reverse=True,
        ):
            contribution_score = round(contribution_raw, 4)
            meta = MonitoringService._FEATURE_META.get(
                key,
                {"label": key.replace("_", " ").title(), "unit": "", "route_target": ""},
            )
            shap_entry = top_features_index.get(key, {})
            snapshot_value = feature_snapshot.get(key)
            if snapshot_value is None:
                if key == "sys_bp":
                    snapshot_value = raw_vitals.get("blood_pressure_sys")
                elif key == "dia_bp":
                    snapshot_value = raw_vitals.get("blood_pressure_dia")
                elif key == "body_temp":
                    snapshot_value = raw_vitals.get("temperature")
                elif key == "resp_rate":
                    snapshot_value = raw_vitals.get("respiratory_rate")
                else:
                    snapshot_value = raw_vitals.get(key)
            if snapshot_value is None and "feature_value" in shap_entry:
                snapshot_value = shap_entry.get("feature_value")

            if contribution_score >= 0.5:
                impact_level = "high"
            elif contribution_score >= 0.2:
                impact_level = "medium"
            else:
                impact_level = "low"

            breakdown.append(
                FactorBreakdownResponse(
                    key=key,
                    label=meta["label"],
                    contribution_score=contribution_score,
                    impact_level=impact_level,
                    value=MonitoringService._format_metric_value(snapshot_value),
                    unit=meta["unit"],
                    route_target=meta["route_target"],
                    direction=str(shap_entry.get("direction") or ""),
                    reason=str(shap_entry.get("reason") or ""),
                )
            )
        return breakdown

    @staticmethod
    def _build_ai_explanation(
        ai_explanation: dict[str, Any],
        fallback_recommendations: list[str] | None = None,
    ) -> AiExplanationResponse | None:
        """Build AiExplanationResponse from stored JSON payload when present."""
        if not ai_explanation:
            return None
        actions_raw = ai_explanation.get("recommended_actions")
        if not isinstance(actions_raw, list):
            actions_raw = []
        actions = [str(item) for item in actions_raw if str(item).strip()]
        if not actions and fallback_recommendations:
            actions = list(fallback_recommendations)
        short_text = str(ai_explanation.get("short_text") or "").strip()
        clinical_note = str(ai_explanation.get("clinical_note") or "").strip()
        if not short_text and not clinical_note and not actions:
            return None
        return AiExplanationResponse(
            short_text=short_text,
            clinical_note=clinical_note,
            recommended_actions=actions,
        )

    @staticmethod
    def _build_snapshot(feature_snapshot: dict[str, Any], raw_vitals: dict[str, Any]) -> SnapshotMetricsResponse:
        heart_rate = raw_vitals.get("heart_rate", feature_snapshot.get("heart_rate"))
        spo2 = raw_vitals.get("spo2", feature_snapshot.get("spo2"))
        sys_bp = raw_vitals.get("blood_pressure_sys", feature_snapshot.get("sys_bp"))
        dia_bp = raw_vitals.get("blood_pressure_dia", feature_snapshot.get("dia_bp"))
        body_temp = raw_vitals.get("temperature", feature_snapshot.get("body_temp"))
        hrv = raw_vitals.get("hrv", feature_snapshot.get("hrv"))
        map_val = feature_snapshot.get("map_val")
        if map_val is None and sys_bp is not None and dia_bp is not None:
            map_val = (MonitoringService._safe_float(sys_bp) + 2 * MonitoringService._safe_float(dia_bp)) / 3

        return SnapshotMetricsResponse(
            heart_rate=MonitoringService._safe_int(heart_rate),
            spo2=MonitoringService._safe_int(spo2),
            sys_bp=MonitoringService._safe_int(sys_bp),
            dia_bp=MonitoringService._safe_int(dia_bp),
            body_temp=round(MonitoringService._safe_float(body_temp), 1),
            hrv=MonitoringService._safe_int(hrv),
            map_val=MonitoringService._safe_int(map_val),
        )

    @staticmethod
    def _compute_trend_7d(
        patient_id: int,
        risk_type: str,
        reference_time: datetime,
        db: Session,
    ) -> list[int]:
        start_time = reference_time - timedelta(days=6)
        rows = db.execute(
            text(
                """
                SELECT calculated_at, score, risk_level, algorithm, features
                FROM risk_scores
                WHERE user_id = :user_id
                  AND risk_type = :risk_type
                  AND calculated_at >= :start_time
                  AND calculated_at <= :end_time
                ORDER BY calculated_at ASC
                """
            ),
            {
                "user_id": patient_id,
                "risk_type": risk_type,
                "start_time": start_time,
                "end_time": reference_time,
            },
        ).mappings().all()

        daily_max: dict[str, int] = {}
        for raw_row in rows:
            normalized = MonitoringService._normalize_risk_row(dict(raw_row))
            day_key = normalized.timestamp.date().isoformat()
            daily_max[day_key] = max(
                daily_max.get(day_key, 0),
                MonitoringService._safe_int(normalized.risk_score),
            )

        trend_points: list[int] = []
        for days_ago in range(6, -1, -1):
            day = (reference_time - timedelta(days=days_ago)).date().isoformat()
            trend_points.append(daily_max.get(day, 0))
        return trend_points

    @staticmethod
    def _select_latest_risk_row(patient_id: int, db: Session) -> dict[str, Any] | None:
        latest_risk_row = db.execute(
            text(
                """
                SELECT
                    id,
                    risk_type,
                    score,
                    risk_level,
                    calculated_at,
                    features,
                    algorithm
                FROM risk_scores
                WHERE user_id = :user_id
                ORDER BY calculated_at DESC
                LIMIT 1
                """
            ),
            {"user_id": patient_id},
        ).mappings().first()
        return dict(latest_risk_row) if latest_risk_row else None

    @staticmethod
    def _select_latest_active_device(patient_id: int, db: Session) -> dict[str, Any] | None:
        try:
            row = db.execute(
                text(
                    """
                    SELECT
                        d.id AS device_id,
                        MAX(v.time) AS latest_vitals_at
                    FROM devices d
                    LEFT JOIN vitals v
                        ON v.device_id = d.id
                    WHERE d.user_id = :user_id
                      AND d.deleted_at IS NULL
                      AND COALESCE(d.is_active, TRUE) = TRUE
                    GROUP BY d.id
                    ORDER BY latest_vitals_at DESC NULLS LAST, d.id DESC
                    LIMIT 1
                    """
                ),
                {"user_id": patient_id},
            ).mappings().first()
        except ProgrammingError as error:
            db.rollback()
            if 'relation "devices" does not exist' in str(error) or 'relation "vitals" does not exist' in str(error):
                return None
            raise

        if row is None:
            return None

        row_dict = dict(row)
        if row_dict.get("latest_vitals_at") is None:
            return None
        return row_dict

    @staticmethod
    def _should_refresh_risk_report(
        latest_risk_row: dict[str, Any] | None,
        latest_vitals_at: datetime | None,
    ) -> bool:
        if latest_vitals_at is None:
            return False
        if latest_risk_row is None:
            return True

        latest_risk_at = latest_risk_row.get("calculated_at")
        if latest_risk_at is None:
            return True

        latest_risk_at = (
            latest_risk_at if latest_risk_at.tzinfo is not None else latest_risk_at.replace(tzinfo=UTC)
        )
        latest_vitals_at = (
            latest_vitals_at if latest_vitals_at.tzinfo is not None else latest_vitals_at.replace(tzinfo=UTC)
        )
        return is_risk_report_stale(latest_risk_at) and latest_vitals_at > latest_risk_at

    @staticmethod
    def _refresh_latest_risk_row(patient_id: int, db: Session) -> dict[str, Any] | None:
        """Return the latest persisted risk row without triggering inline ML inference.

        Inline ``calculate_device_risk`` inside a GET read path blocks the
        request thread on a full model-api round-trip for every stale contact
        in the dashboard.  Risk scores are refreshed by the telemetry ingest
        pipeline on every vitals batch — the read path should only surface
        what is already persisted.
        """
        return MonitoringService._select_latest_risk_row(patient_id, db)

    @staticmethod
    def _previous_risk_score(
        patient_id: int,
        risk_type: str,
        current_timestamp: datetime,
        db: Session,
    ) -> float | None:
        previous_row = db.execute(
            text(
                """
                SELECT score, risk_level, algorithm, features
                FROM risk_scores
                WHERE user_id = :user_id
                  AND risk_type = :risk_type
                  AND calculated_at < :current_timestamp
                ORDER BY calculated_at DESC
                LIMIT 1
                """
            ),
            {
                "user_id": patient_id,
                "risk_type": risk_type,
                "current_timestamp": current_timestamp,
            },
        ).mappings().first()
        if previous_row is None:
            return None

        normalized = MonitoringService._normalize_risk_row(dict(previous_row))
        return normalized.risk_score

    @staticmethod
    def _get_history_summary(
        patient_id: int,
        range_key: str,
        db: Session,
    ) -> RiskHistorySummaryResponse:
        days = MonitoringService.RISK_HISTORY_RANGE_DAYS.get(range_key, 7)
        current_start = datetime.now(UTC) - timedelta(days=days)
        previous_start = current_start - timedelta(days=days)

        current_rows = db.execute(
            text(
                """
                SELECT calculated_at, score, risk_level, algorithm, features
                FROM risk_scores
                WHERE user_id = :user_id
                  AND calculated_at >= :current_start
                ORDER BY calculated_at ASC
                """
            ),
            {"user_id": patient_id, "current_start": current_start},
        ).mappings().all()

        previous_rows = db.execute(
            text(
                """
                SELECT calculated_at, score, risk_level, algorithm, features
                FROM risk_scores
                WHERE user_id = :user_id
                  AND calculated_at >= :previous_start
                  AND calculated_at < :current_start
                ORDER BY calculated_at ASC
                """
            ),
            {
                "user_id": patient_id,
                "previous_start": previous_start,
                "current_start": current_start,
            },
        ).mappings().all()

        current_scores = [
            MonitoringService._normalize_risk_row(dict(row)).risk_score
            for row in current_rows
        ]
        previous_scores = [
            MonitoringService._normalize_risk_row(dict(row)).risk_score
            for row in previous_rows
        ]

        average_score = round(sum(current_scores) / len(current_scores), 2) if current_scores else 0.0
        highest_score = round(max(current_scores), 2) if current_scores else 0.0
        lowest_score = round(min(current_scores), 2) if current_scores else 0.0
        previous_average = (
            round(sum(previous_scores) / len(previous_scores), 2)
            if previous_scores
            else average_score
        )
        delta_vs_previous_period = round(average_score - previous_average, 2)

        trend_map: dict[str, int] = {}
        for row in current_rows:
            normalized = MonitoringService._normalize_risk_row(dict(row))
            day_key = normalized.timestamp.date().isoformat()
            trend_map[day_key] = max(
                trend_map.get(day_key, 0),
                MonitoringService._safe_int(normalized.risk_score),
            )

        trend_points: list[int] = []
        for days_ago in range(min(days - 1, 6), -1, -1):
            day_key = (datetime.now(UTC) - timedelta(days=days_ago)).date().isoformat()
            trend_points.append(trend_map.get(day_key, 0))

        return RiskHistorySummaryResponse(
            average_score=average_score,
            highest_score=highest_score,
            lowest_score=lowest_score,
            delta_vs_previous_period=delta_vs_previous_period,
            trend_points=trend_points,
        )

    @staticmethod
    def get_latest_vital_signs(patient_id: int, db: Session) -> VitalSignsResponse:
        try:
            row = db.execute(
                text(
                    """
                    SELECT
                        v.time,
                        v.heart_rate,
                        v.spo2,
                        v.temperature,
                        v.respiratory_rate,
                        v.blood_pressure_sys,
                        v.blood_pressure_dia,
                        v.signal_quality
                    FROM vitals v
                    INNER JOIN devices d ON v.device_id = d.id
                    WHERE d.user_id = :user_id
                    ORDER BY v.time DESC
                    LIMIT 1
                    """
                ),
                {"user_id": patient_id},
            ).mappings().first()

            if row is None:
                raise ValueError("No vital signs data found for this user")

            is_stale = datetime.now(UTC) - row["time"] > MonitoringService.VITALS_STALE_AFTER
            return VitalSignsResponse(
                heart_rate=MonitoringService._safe_float(row["heart_rate"]) if row["heart_rate"] is not None else None,
                spo2=MonitoringService._safe_float(row["spo2"]) if row["spo2"] is not None else None,
                temperature=MonitoringService._safe_float(row["temperature"]) if row["temperature"] is not None else None,
                respiratory_rate=MonitoringService._safe_float(row["respiratory_rate"]) if row["respiratory_rate"] is not None else None,
                blood_pressure_sys=MonitoringService._safe_float(row["blood_pressure_sys"]) if row["blood_pressure_sys"] is not None else None,
                blood_pressure_dia=MonitoringService._safe_float(row["blood_pressure_dia"]) if row["blood_pressure_dia"] is not None else None,
                timestamp=row["time"],
                is_stale=is_stale,
            )
        except ProgrammingError as error:
            db.rollback()
            if 'relation "vitals" does not exist' in str(error):
                raise ValueError("Vital signs table not initialized")
            raise

    # F-12 (M-6): supported (window_hours, bucket_minutes) per range key.
    # Only "24h" is wired into the mobile UI today; "7d" / "30d" are
    # reserved for future ticket scope and currently coerced to 24h. The
    # bucket sizes are tuned so each chart renders ~50–170 points: large
    # enough to show diurnal variation, small enough to keep the JSON
    # payload under ~10 KB and the fl_chart line smooth on a phone.
    _VITALS_TIMESERIES_RANGES: dict[str, tuple[int, int]] = {
        "24h": (24, 15),  # 96 buckets
        "7d": (24 * 7, 60),  # 168 buckets — reserved for future range tab
        "30d": (24 * 30, 6 * 60),  # 120 buckets — reserved for future range tab
    }

    @staticmethod
    def get_vitals_timeseries(
        patient_id: int,
        db: Session,
        range_key: str = "24h",
    ) -> VitalsTimeseriesResponse:
        """Return downsampled vitals time-series for the chart UI.

        F-12 (M-6) — backs the new ``GET /mobile/metrics/vitals/timeseries``
        endpoint. The mobile ``vital_detail_screen.dart`` previously
        rendered an "EmptyChartPlaceholder" because
        :attr:`VitalSignsProvider.chartData` was hardcoded to ``const []``.
        This method re-buckets raw ``vitals`` rows into ~96 points (15 min
        × 24 h) using TimescaleDB ``time_bucket`` and returns one row per
        bucket with every channel populated, so the screen can switch
        between heart_rate / SpO₂ / blood-pressure tabs without an extra
        round trip.

        Returns an empty payload (200 with ``data: []``) when:
          * the patient has no vitals in the window, or
          * the ``vitals`` hypertable doesn't exist yet (e.g. fresh DB).

        We deliberately return 200 + empty list rather than 404 so the
        mobile chart can render its "no data" placeholder without an
        error toast — same convention the existing
        ``MonitoringService.get_sleep_history`` uses.
        """
        normalized_range = (
            range_key
            if range_key in MonitoringService._VITALS_TIMESERIES_RANGES
            else "24h"
        )
        window_hours, bucket_minutes = MonitoringService._VITALS_TIMESERIES_RANGES[
            normalized_range
        ]

        # `time_bucket(:bucket_interval, ...)` expects a string interval
        # like '15 minutes'. Building it server-side (rather than as a
        # raw f-string) keeps the column list parameterised so a malicious
        # bucket value can't smuggle SQL through the route.
        bucket_interval = f"{bucket_minutes} minutes"
        window_interval = f"{window_hours} hours"

        try:
            rows = db.execute(
                text(
                    """
                    SELECT
                        time_bucket(CAST(:bucket_interval AS interval), v.time) AS bucket_ts,
                        AVG(v.heart_rate) AS heart_rate,
                        AVG(v.spo2) AS spo2,
                        AVG(v.temperature) AS temperature,
                        AVG(v.respiratory_rate) AS respiratory_rate,
                        AVG(v.blood_pressure_sys) AS blood_pressure_sys,
                        AVG(v.blood_pressure_dia) AS blood_pressure_dia
                    FROM vitals v
                    INNER JOIN devices d ON v.device_id = d.id
                    WHERE d.user_id = :user_id
                      AND v.time > NOW() - CAST(:window_interval AS interval)
                    GROUP BY bucket_ts
                    ORDER BY bucket_ts ASC
                    """
                ),
                {
                    "bucket_interval": bucket_interval,
                    "user_id": patient_id,
                    "window_interval": window_interval,
                },
            ).mappings().all()
        except ProgrammingError as error:
            db.rollback()
            message = str(error)
            # Fresh DB without the hypertable — return an empty envelope
            # rather than 500-ing the chart screen.
            if 'relation "vitals" does not exist' in message:
                return VitalsTimeseriesResponse(
                    range=normalized_range,
                    bucket_minutes=bucket_minutes,
                )
            raise

        points: list[VitalsTimeseriesPointResponse] = []
        for row in rows:
            row_dict = dict(row)
            points.append(
                VitalsTimeseriesPointResponse(
                    ts=row_dict["bucket_ts"],
                    heart_rate=MonitoringService._safe_float(row_dict.get("heart_rate"))
                    if row_dict.get("heart_rate") is not None
                    else None,
                    spo2=MonitoringService._safe_float(row_dict.get("spo2"))
                    if row_dict.get("spo2") is not None
                    else None,
                    temperature=MonitoringService._safe_float(row_dict.get("temperature"))
                    if row_dict.get("temperature") is not None
                    else None,
                    respiratory_rate=MonitoringService._safe_float(
                        row_dict.get("respiratory_rate")
                    )
                    if row_dict.get("respiratory_rate") is not None
                    else None,
                    blood_pressure_sys=MonitoringService._safe_float(
                        row_dict.get("blood_pressure_sys")
                    )
                    if row_dict.get("blood_pressure_sys") is not None
                    else None,
                    blood_pressure_dia=MonitoringService._safe_float(
                        row_dict.get("blood_pressure_dia")
                    )
                    if row_dict.get("blood_pressure_dia") is not None
                    else None,
                )
            )

        return VitalsTimeseriesResponse(
            range=normalized_range,
            bucket_minutes=bucket_minutes,
            data=points,
        )

    @staticmethod
    def get_latest_sleep_session(patient_id: int, db: Session) -> SleepSessionResponse | None:
        try:
            row = db.execute(
                text(
                    """
                    SELECT
                        start_time,
                        end_time,
                        sleep_score,
                        wake_count,
                        phases,
                        sleep_date
                    FROM sleep_sessions
                    WHERE user_id = :user_id
                    ORDER BY sleep_date DESC NULLS LAST, start_time DESC
                    LIMIT 1
                    """
                ),
                {"user_id": patient_id},
            ).mappings().first()
        except ProgrammingError as error:
            db.rollback()
            if 'relation "sleep_sessions" does not exist' in str(error):
                return None
            raise

        if row is None:
            return None

        return MonitoringService._build_sleep_session_response(dict(row))

    @staticmethod
    def get_sleep_history(
        patient_id: int,
        db: Session,
        from_date: str | None = None,
        to_date: str | None = None,
        limit: int = 30,
    ) -> list[SleepSessionResponse]:
        try:
            where_clause = "user_id = :user_id"
            params: dict[str, Any] = {"user_id": patient_id, "limit": limit}

            if from_date:
                normalized_from_date = MonitoringService._normalize_sleep_date(from_date)
                if normalized_from_date is not None:
                    params["from_date"] = normalized_from_date
                    where_clause += " AND sleep_date >= :from_date"
            if to_date:
                normalized_to_date = MonitoringService._normalize_sleep_date(to_date)
                if normalized_to_date is not None:
                    params["to_date"] = normalized_to_date
                    where_clause += " AND sleep_date <= :to_date"

            rows = db.execute(
                text(
                    f"""
                    SELECT
                        start_time,
                        end_time,
                        sleep_score,
                        wake_count,
                        phases,
                        sleep_date
                    FROM sleep_sessions
                    WHERE {where_clause}
                    ORDER BY sleep_date DESC NULLS LAST, start_time DESC
                    LIMIT :limit
                    """
                ),
                params,
            ).mappings().all()
        except ProgrammingError as error:
            db.rollback()
            if 'relation "sleep_sessions" does not exist' in str(error):
                return []
            raise

        return [MonitoringService._build_sleep_session_response(dict(row)) for row in rows]

    @staticmethod
    def get_health_report(patient_id: int, db: Session) -> HealthReportResponse:
        vitals_dict: dict[str, Any] = {}
        try:
            # Aliases below MUST match the Flutter `HealthReport.vitals24hAvg`
            # contract documented in
            # `lib/features/health_monitoring/models/health_report.dart`. The
            # screen `_VitalsAvgGrid` reads these exact keys; renaming them
            # silently breaks the 24-hour averages section.
            vitals_stats = db.execute(
                text(
                    """
                    SELECT
                        ROUND(AVG(heart_rate)::numeric, 1) AS heart_rate,
                        ROUND(AVG(spo2)::numeric, 1) AS spo2,
                        ROUND(AVG(temperature)::numeric, 1) AS temperature,
                        ROUND(AVG(respiratory_rate)::numeric, 1) AS respiratory_rate,
                        ROUND(AVG(blood_pressure_sys)::numeric, 0) AS blood_pressure_sys,
                        ROUND(AVG(blood_pressure_dia)::numeric, 0) AS blood_pressure_dia
                    FROM vitals v
                    INNER JOIN devices d ON v.device_id = d.id
                    WHERE d.user_id = :user_id
                      AND v.time > NOW() - INTERVAL '24 hours'
                    """
                ),
                {"user_id": patient_id},
            ).mappings().first()
        except Exception:
            logger.exception("Failed to aggregate vitals stats for patient_id=%s", patient_id)
            vitals_stats = None

        vitals_dict = dict(vitals_stats) if vitals_stats else {}

        try:
            latest_risk_row = MonitoringService._refresh_latest_risk_row(patient_id, db)
        except Exception:
            logger.exception(
                "Failed to refresh health report for patient_id=%s; using latest persisted risk row",
                patient_id,
            )
            latest_risk_row = MonitoringService._select_latest_risk_row(patient_id, db)

        if latest_risk_row is None:
            return HealthReportResponse(vitals_24h_avg=vitals_dict)

        try:
            normalized = MonitoringService._normalize_risk_row(dict(latest_risk_row))
            return HealthReportResponse(
                vitals_24h_avg=vitals_dict,
                latest_risk_score=normalized.risk_score,
                risk_level=normalized.risk_level,
                risk_type=normalized.risk_type,
                last_updated=normalized.timestamp,
                health_score=normalized.health_score,
                health_level=normalized.health_level,
                health_summary=normalized.health_summary,
                confidence=normalized.confidence,
                is_stale=normalized.is_stale,
            )
        except Exception:
            logger.exception(
                "Failed to normalize latest risk row for patient_id=%s; returning vitals-only health report",
                patient_id,
            )
            return HealthReportResponse(vitals_24h_avg=vitals_dict)

    @staticmethod
    def get_risk_reports(patient_id: int, db: Session, limit: int = 10) -> list[RiskReportResponse]:
        try:
            rows = db.execute(
                text(
                    """
                    SELECT
                        rs.id,
                        rs.risk_type,
                        rs.score,
                        rs.risk_level,
                        rs.calculated_at,
                        rs.features,
                        rs.algorithm,
                        re.explanation_text,
                        re.feature_importance,
                        re.recommendations,
                        re.top_features_json,
                        re.ai_explanation_json,
                        re.shap_details_json,
                        re.model_request_id,
                        re.audience_payload_json
                    FROM risk_scores rs
                    LEFT JOIN LATERAL (
                        SELECT id AS risk_explanation_id,
                               explanation_text,
                               feature_importance,
                               recommendations,
                               top_features_json,
                               ai_explanation_json,
                               shap_details_json,
                               model_request_id,
                               audience_payload_json
                        FROM risk_explanations
                        WHERE risk_score_id = rs.id
                        ORDER BY id DESC
                        LIMIT 1
                    ) re ON TRUE
                    WHERE rs.user_id = :user_id
                    ORDER BY rs.calculated_at DESC
                    LIMIT :limit
                    """
                ),
                {"user_id": patient_id, "limit": limit},
            ).mappings().all()
        except ProgrammingError:
            return []

        reports: list[RiskReportResponse] = []
        for raw_row in rows:
            normalized = MonitoringService._normalize_risk_row(dict(raw_row))
            previous_score = MonitoringService._previous_risk_score(
                patient_id,
                normalized.risk_type,
                normalized.timestamp,
                db,
            )
            trend_7d = MonitoringService._compute_trend_7d(
                patient_id,
                normalized.risk_type,
                normalized.timestamp,
                db,
            )
            top_factors = MonitoringService._top_factors(
                normalized.feature_importance,
                top_features=normalized.top_features,
            )
            reports.append(
                build_risk_report(
                    normalized,
                    previous_score=previous_score,
                    trend_7d=trend_7d,
                    top_factors=top_factors,
                )
            )
        return reports

    @staticmethod
    def get_risk_report_detail(patient_id: int, report_id: int, db: Session) -> RiskReportDetailResponse | None:
        try:
            risk_row = db.execute(
                text(
                    """
                    SELECT
                        rs.id,
                        rs.user_id,
                        rs.risk_type,
                        rs.score,
                        rs.risk_level,
                        rs.calculated_at,
                        rs.features,
                        rs.model_version,
                        rs.algorithm,
                        re.id AS risk_explanation_id,
                        re.explanation_text,
                        re.feature_importance,
                        re.recommendations,
                        re.top_features_json,
                        re.ai_explanation_json,
                        re.shap_details_json,
                        re.model_request_id,
                        re.audience_payload_json
                    FROM risk_scores rs
                    LEFT JOIN LATERAL (
                        SELECT id,
                               explanation_text,
                               feature_importance,
                               recommendations,
                               top_features_json,
                               ai_explanation_json,
                               shap_details_json,
                               model_request_id,
                               audience_payload_json
                        FROM risk_explanations
                        WHERE risk_score_id = rs.id
                        ORDER BY id DESC
                        LIMIT 1
                    ) re ON TRUE
                    WHERE rs.id = :report_id
                      AND rs.user_id = :user_id
                    LIMIT 1
                    """
                ),
                {"report_id": report_id, "user_id": patient_id},
            ).mappings().first()
        except ProgrammingError:
            return None

        if risk_row is None:
            return None

        row_dict = dict(risk_row)
        cached = MonitoringService._read_audience_cache(
            row_dict, audience="patient", model=RiskReportDetailResponse,
        )
        if cached is not None:
            return cached
        result = build_risk_report_detail(
            **MonitoringService._build_detail_inputs(patient_id, row_dict, db),
        )
        MonitoringService._write_audience_cache(
            db, row_dict, audience="patient", payload=result,
        )
        return result

    @staticmethod
    def get_risk_report_clinician_detail(
        patient_id: int, report_id: int, db: Session,
    ) -> RiskReportClinicianResponse | None:
        """Phase 5 clinician variant of :meth:`get_risk_report_detail`.

        Same SQL fetch + assembly as the patient flow; only the final
        builder differs. Role gating is enforced at the route layer
        (``app/core/audience.require_clinician_audience``) so this
        method trusts that the caller has already verified the
        permission.
        """
        try:
            risk_row = db.execute(
                text(
                    """
                    SELECT
                        rs.id,
                        rs.user_id,
                        rs.risk_type,
                        rs.score,
                        rs.risk_level,
                        rs.calculated_at,
                        rs.features,
                        rs.model_version,
                        rs.algorithm,
                        re.id AS risk_explanation_id,
                        re.explanation_text,
                        re.feature_importance,
                        re.recommendations,
                        re.top_features_json,
                        re.ai_explanation_json,
                        re.shap_details_json,
                        re.model_request_id,
                        re.audience_payload_json
                    FROM risk_scores rs
                    LEFT JOIN LATERAL (
                        SELECT id,
                               explanation_text,
                               feature_importance,
                               recommendations,
                               top_features_json,
                               ai_explanation_json,
                               shap_details_json,
                               model_request_id,
                               audience_payload_json
                        FROM risk_explanations
                        WHERE risk_score_id = rs.id
                        ORDER BY id DESC
                        LIMIT 1
                    ) re ON TRUE
                    WHERE rs.id = :report_id
                      AND rs.user_id = :user_id
                    LIMIT 1
                    """
                ),
                {"report_id": report_id, "user_id": patient_id},
            ).mappings().first()
        except ProgrammingError:
            return None

        if risk_row is None:
            return None

        row_dict = dict(risk_row)
        cached = MonitoringService._read_audience_cache(
            row_dict, audience="clinician", model=RiskReportClinicianResponse,
        )
        if cached is not None:
            return cached
        result = build_risk_report_clinician_detail(
            **MonitoringService._build_detail_inputs(patient_id, row_dict, db),
        )
        MonitoringService._write_audience_cache(
            db, row_dict, audience="clinician", payload=result,
        )
        return result

    @staticmethod
    def _read_audience_cache(
        row_dict: dict[str, Any],
        *,
        audience: str,
        model: type[Any],
    ) -> Any | None:
        """Return the cached DTO for ``audience`` if it matches the current
        contract version, else ``None`` (signalling cache miss / stale).

        Cache shape:
        ``{"<audience>": {"contract_version": "x.y.z", "payload": {...}}}``.

        Phase 7: ``RISK_CONTRACT_VERSION`` is the cache key suffix so a
        contract bump invalidates every entry without a manual flush.
        """
        cache = row_dict.get("audience_payload_json")
        if not isinstance(cache, dict):
            record_timing(
                "build_dto", 0.0, audience=audience, cache="miss",
                reason="no_cache_column",
            )
            return None
        entry = cache.get(audience)
        if not isinstance(entry, dict):
            record_timing(
                "build_dto", 0.0, audience=audience, cache="miss",
                reason="no_audience_entry",
            )
            return None
        version = entry.get("contract_version")
        payload = entry.get("payload")
        if version != RISK_CONTRACT_VERSION or not isinstance(payload, dict):
            record_timing(
                "build_dto", 0.0, audience=audience, cache="miss",
                reason="version_mismatch" if version != RISK_CONTRACT_VERSION else "malformed_payload",
            )
            return None
        try:
            result = model.model_validate(payload)
        except Exception:  # noqa: BLE001 - fall back to rebuild on any parse error
            logger.exception(
                "Audience cache hit but payload failed validation; rebuilding"
            )
            record_timing(
                "build_dto", 0.0, audience=audience, cache="miss",
                reason="payload_validate_failed",
            )
            return None
        record_timing("build_dto", 0.0, audience=audience, cache="hit")
        return result

    @staticmethod
    def _write_audience_cache(
        db: Session,
        row_dict: dict[str, Any],
        *,
        audience: str,
        payload: Any,
    ) -> None:
        """Best-effort write the freshly-built ``payload`` to the cache column.

        Merges with whatever is already in ``audience_payload_json`` so a
        patient-built request that lands first does not erase a clinician
        entry written later (or vice versa). Failures are logged but never
        propagated — the request flow already has the freshly-built payload.
        """
        risk_explanation_id = row_dict.get("risk_explanation_id")
        if risk_explanation_id is None:
            # Legacy / synthetic rows that come through ``_get_history_summary``
            # without the LATERAL join. Cache write is a no-op for them.
            return
        existing = row_dict.get("audience_payload_json")
        merged: dict[str, Any] = dict(existing) if isinstance(existing, dict) else {}
        merged[audience] = {
            "contract_version": RISK_CONTRACT_VERSION,
            "payload": payload.model_dump(mode="json"),
        }
        try:
            db.execute(
                text(
                    """
                    UPDATE risk_explanations
                    SET audience_payload_json = CAST(:cache AS jsonb)
                    WHERE id = :risk_explanation_id
                    """
                ),
                {
                    "cache": json.dumps(merged),
                    "risk_explanation_id": int(risk_explanation_id),
                },
            )
            db.commit()
            # Reflect the new state in the row_dict so a sibling cache read
            # within the same request sees the freshly written entry.
            row_dict["audience_payload_json"] = merged
        except Exception:  # noqa: BLE001 - cache write must never break the request flow
            db.rollback()
            logger.exception(
                "Failed to write audience cache for risk_explanation_id=%s audience=%s",
                risk_explanation_id,
                audience,
            )

    @staticmethod
    def _build_detail_inputs(
        patient_id: int,
        raw_row: dict[str, Any],
        db: Session,
    ) -> dict[str, Any]:
        """Shared assembly for the patient + clinician detail builders.

        Phase 5 split this out of :meth:`get_risk_report_detail` so the
        new clinician variant can call the same builder with the same
        input set without duplicating the four service-layer calls
        (``_previous_risk_score``, ``_compute_trend_7d``,
        ``_build_breakdown``, ``_build_ai_explanation``).
        """
        normalized = MonitoringService._normalize_risk_row(raw_row)
        previous_score = MonitoringService._previous_risk_score(
            patient_id,
            normalized.risk_type,
            normalized.timestamp,
            db,
        )
        trend_7d = MonitoringService._compute_trend_7d(
            patient_id,
            normalized.risk_type,
            normalized.timestamp,
            db,
        )
        top_features = normalized.top_features
        breakdown = MonitoringService._build_breakdown(
            normalized.feature_importance,
            normalized.feature_snapshot,
            normalized.raw_vitals,
            top_features=top_features,
        )
        snapshot = MonitoringService._build_snapshot(
            normalized.feature_snapshot,
            normalized.raw_vitals,
        )
        top_factors = MonitoringService._top_factors(
            normalized.feature_importance,
            top_features=top_features,
        )
        ai_explanation = MonitoringService._build_ai_explanation(
            normalized.ai_explanation,
            fallback_recommendations=normalized.recommendations,
        )
        return {
            "normalized": normalized,
            "previous_score": previous_score,
            "trend_7d": trend_7d,
            "top_factors": top_factors,
            "breakdown": breakdown,
            "snapshot": snapshot,
            "ai_explanation": ai_explanation,
        }

    #: Allow-listed values for the ``risk_type`` filter on
    #: ``get_risk_history``. Phase 4A-full slice 3b — Flutter exposes
    #: a filter chip row over these values plus an "All" pseudo-option
    #: that omits the filter entirely. Anything outside the allow-list
    #: is silently treated as "no filter" so a future client passing a
    #: typo doesn't blow up the screen.
    RISK_HISTORY_TYPE_FILTERS: frozenset[str] = frozenset({
        "general", "sleep", "fall",
    })

    @staticmethod
    def get_risk_history(
        patient_id: int,
        db: Session,
        range_key: str = "7d",
        page: int = 1,
        limit: int = 20,
        risk_type: str | None = None,
    ) -> RiskHistoryResponse:
        range_key = range_key if range_key in MonitoringService.RISK_HISTORY_RANGE_DAYS else "7d"
        days = MonitoringService.RISK_HISTORY_RANGE_DAYS[range_key]
        page = max(page, 1)
        limit = max(1, min(limit, 100))
        offset = (page - 1) * limit
        start_time = datetime.now(UTC) - timedelta(days=days)

        # Phase 4A-full slice 3b: optional ``risk_type`` filter.
        # Empty / missing / unknown values fall back to "no filter" so
        # the route is forward-compatible with future risk_type values
        # the backend doesn't recognise yet.
        normalized_risk_type: str | None = None
        if risk_type:
            stripped = risk_type.strip().lower()
            if stripped in MonitoringService.RISK_HISTORY_TYPE_FILTERS:
                normalized_risk_type = stripped

        try:
            count_sql = (
                """
                SELECT COUNT(*)
                FROM risk_scores
                WHERE user_id = :user_id
                  AND calculated_at >= :start_time
                """
            )
            if normalized_risk_type is not None:
                count_sql += "  AND risk_type = :risk_type\n"

            count_params: dict[str, Any] = {
                "user_id": patient_id, "start_time": start_time,
            }
            if normalized_risk_type is not None:
                count_params["risk_type"] = normalized_risk_type
            total = db.execute(text(count_sql), count_params).scalar() or 0

            list_sql = (
                """
                SELECT
                    rs.id,
                    rs.risk_type,
                    rs.score,
                    rs.risk_level,
                    rs.calculated_at,
                    rs.features,
                    rs.algorithm,
                    re.explanation_text
                FROM risk_scores rs
                LEFT JOIN LATERAL (
                    SELECT explanation_text
                    FROM risk_explanations
                    WHERE risk_score_id = rs.id
                    ORDER BY id DESC
                    LIMIT 1
                ) re ON TRUE
                WHERE rs.user_id = :user_id
                  AND rs.calculated_at >= :start_time
                """
            )
            if normalized_risk_type is not None:
                list_sql += "  AND rs.risk_type = :risk_type\n"
            list_sql += (
                """ORDER BY rs.calculated_at DESC
                OFFSET :offset
                LIMIT :limit
                """
            )

            list_params: dict[str, Any] = {
                "user_id": patient_id,
                "start_time": start_time,
                "offset": offset,
                "limit": limit,
            }
            if normalized_risk_type is not None:
                list_params["risk_type"] = normalized_risk_type
            rows = db.execute(text(list_sql), list_params).mappings().all()
        except ProgrammingError:
            return RiskHistoryResponse(
                range=range_key,
                summary=RiskHistorySummaryResponse(),
                items=[],
                page=page,
                limit=limit,
                has_more=False,
            )

        items: list[RiskHistoryItemResponse] = []
        for raw_row in rows:
            normalized = MonitoringService._normalize_risk_row(dict(raw_row))
            items.append(build_risk_history_item(normalized))

        summary = MonitoringService._get_history_summary(patient_id, range_key, db)
        return RiskHistoryResponse(
            range=range_key,
            summary=summary,
            items=items,
            page=page,
            limit=limit,
            has_more=offset + len(items) < int(total),
        )
