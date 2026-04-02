from __future__ import annotations

from datetime import UTC, datetime, timedelta
import hashlib
import json

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.schemas.monitoring import SleepSessionResponse, VitalSignsResponse, HealthReportResponse, RiskReportResponse, RiskReportDetailResponse


class MonitoringService:
    """Fetch real-time telemetry from database - NO MOCK DATA."""

    VITALS_STALE_AFTER = timedelta(seconds=30)

    @staticmethod
    def _calculate_sleep_metrics(
        phases: dict,
        quality_score: int,
        in_bed_minutes: int,
    ) -> tuple[int, int, float, str]:
        """Calculate derived sleep metrics from phases and quality score."""
        sleep_minutes = phases.get('light', 0) + phases.get('deep', 0) + phases.get('rem', 0)
        awake_minutes = phases.get('awake', 0)
        efficiency_ratio = (
            sleep_minutes / in_bed_minutes if in_bed_minutes > 0 else 0.0
        )
        
        if quality_score >= 70:
            quality_label = "GOOD"
        elif quality_score >= 50:
            quality_label = "AVERAGE"
        else:
            quality_label = "POOR"
        
        return sleep_minutes, awake_minutes, efficiency_ratio, quality_label

    @staticmethod
    def get_latest_vital_signs(patient_id: int, db: Session) -> VitalSignsResponse:
        """
        Query latest vital signs from DB for the user's primary device.
        Returns data from timescale vitals table (real-time).
        """
        try:
            # Get latest vitals for user's device
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

            # Check if data is stale (>5 minutes old)
            is_stale = (datetime.now(UTC) - row["time"]).total_seconds() > 300

            return VitalSignsResponse(
                heart_rate=float(row["heart_rate"]) if row["heart_rate"] else None,
                spo2=float(row["spo2"]) if row["spo2"] else None,
                temperature=float(row["temperature"]) if row["temperature"] else None,
                respiratory_rate=float(row["respiratory_rate"]) if row["respiratory_rate"] else None,
                blood_pressure_sys=float(row["blood_pressure_sys"]) if row["blood_pressure_sys"] else None,
                blood_pressure_dia=float(row["blood_pressure_dia"]) if row["blood_pressure_dia"] else None,
                timestamp=row["time"],
                is_stale=is_stale,
            )
        except ProgrammingError as error:
            db.rollback()
            if 'relation "vitals" does not exist' in str(error):
                raise ValueError("Vital signs table not initialized")
            raise

    @staticmethod
    def get_latest_sleep_session(
        patient_id: int,
        db: Session,
    ) -> SleepSessionResponse | None:
        """
        Query latest sleep session from DB (real data only - no mock).
        Returns None if no data found.
        """
        try:
            row = db.execute(
                text(
                    """
                    SELECT
                        start_time,
                        end_time,
                        sleep_score,
                        wake_count,
                        phases
                    FROM sleep_sessions
                    WHERE user_id = :user_id
                    ORDER BY start_time DESC
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

        # Parse phases from JSONB/JSON
        phases_raw = row.get("phases")
        phases = {"awake": 0, "light": 0, "deep": 0, "rem": 0}

        if isinstance(phases_raw, dict):
            phases = {
                key: int(value)
                for key, value in phases_raw.items()
                if isinstance(value, (int, float))
            }
        elif isinstance(phases_raw, str):
            try:
                parsed = json.loads(phases_raw)
                if isinstance(parsed, dict):
                    phases = {
                        key: int(value)
                        for key, value in parsed.items()
                        if isinstance(value, (int, float))
                    }
            except json.JSONDecodeError:
                pass

        start_time = row["start_time"]
        end_time = row["end_time"]
        in_bed_minutes = max(
            0,
            int((end_time - start_time).total_seconds() // 60),
        )
        
        quality_score = int(row.get("sleep_score") or 0)
        sleep_minutes, awake_minutes, efficiency_ratio, quality_label = (
            MonitoringService._calculate_sleep_metrics(
                phases, quality_score, in_bed_minutes
            )
        )

        return SleepSessionResponse(
            quality_score=quality_score,
            in_bed_minutes=in_bed_minutes,
            wake_count=int(row.get("wake_count") or 0),
            phases=phases,
            start_time=start_time,
            end_time=end_time,
            sleep_minutes=sleep_minutes,
            awake_minutes=awake_minutes,
            efficiency_ratio=efficiency_ratio,
            quality_label=quality_label,
        )

    @staticmethod
    def get_sleep_history(
        patient_id: int,
        db: Session,
        from_date: str | None = None,
        to_date: str | None = None,
        limit: int = 30,
    ) -> list[SleepSessionResponse]:
        """
        Query sleep history from DB within a date range.
        from_date and to_date should be ISO format strings (e.g., "2026-03-23T18:35:42.095752Z").
        Returns list of sleep sessions, sorted by start_time DESC.
        """
        try:
            # Build WHERE clause for date range
            where_clause = "user_id = :user_id"
            params = {"user_id": patient_id, "limit": limit}
            
            if from_date:
                try:
                    from_dt = datetime.fromisoformat(from_date.replace('Z', '+00:00'))
                    where_clause += " AND start_time >= :from_date"
                    params["from_date"] = from_dt
                except (ValueError, AttributeError):
                    pass
                    
            if to_date:
                try:
                    to_dt = datetime.fromisoformat(to_date.replace('Z', '+00:00'))
                    where_clause += " AND end_time <= :to_date"
                    params["to_date"] = to_dt
                except (ValueError, AttributeError):
                    pass

            rows = db.execute(
                text(
                    f"""
                    SELECT
                        start_time,
                        end_time,
                        sleep_score,
                        wake_count,
                        phases
                    FROM sleep_sessions
                    WHERE {where_clause}
                    ORDER BY start_time DESC
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

        results = []
        for row in rows:
            # Parse phases from JSONB/JSON
            phases_raw = row.get("phases")
            phases = {"awake": 0, "light": 0, "deep": 0, "rem": 0}

            if isinstance(phases_raw, dict):
                phases = {
                    key: int(value)
                    for key, value in phases_raw.items()
                    if isinstance(value, (int, float))
                }
            elif isinstance(phases_raw, str):
                try:
                    parsed = json.loads(phases_raw)
                    if isinstance(parsed, dict):
                        phases = {
                            key: int(value)
                            for key, value in parsed.items()
                            if isinstance(value, (int, float))
                        }
                except json.JSONDecodeError:
                    pass

            start_time = row["start_time"]
            end_time = row["end_time"]
            in_bed_minutes = max(
                0,
                int((end_time - start_time).total_seconds() // 60),
            )
            
            quality_score = int(row.get("sleep_score") or 0)
            sleep_minutes, awake_minutes, efficiency_ratio, quality_label = (
                MonitoringService._calculate_sleep_metrics(
                    phases, quality_score, in_bed_minutes
                )
            )

            results.append(
                SleepSessionResponse(
                    quality_score=quality_score,
                    in_bed_minutes=in_bed_minutes,
                    wake_count=int(row.get("wake_count") or 0),
                    phases=phases,
                    start_time=start_time,
                    end_time=end_time,
                    sleep_minutes=sleep_minutes,
                    awake_minutes=awake_minutes,
                    efficiency_ratio=efficiency_ratio,
                    quality_label=quality_label,
                )
            )

        return results

    @staticmethod
    def get_health_report(patient_id: int, db: Session) -> HealthReportResponse:
        """
        Get comprehensive health report:
        - Latest vitals stats (24h average)
        - Current risk scores
        """
        try:
            # Get latest vitals stats (24h average)
            vitals_stats = db.execute(
                text(
                    """
                    SELECT
                        ROUND(AVG(heart_rate)::numeric, 1) as avg_hr,
                        MIN(heart_rate) as min_hr,
                        MAX(heart_rate) as max_hr,
                        ROUND(AVG(spo2)::numeric, 1) as avg_spo2,
                        MIN(spo2) as min_spo2,
                        ROUND(AVG(temperature)::numeric, 1) as avg_temp,
                        ROUND(AVG(blood_pressure_sys)::numeric, 0) as avg_bp_sys,
                        ROUND(AVG(blood_pressure_dia)::numeric, 0) as avg_bp_dia
                    FROM vitals v
                    INNER JOIN devices d ON v.device_id = d.id
                    WHERE d.user_id = :user_id
                    AND v.time > NOW() - INTERVAL '24 hours'
                    """
                ),
                {"user_id": patient_id},
            ).mappings().first()

            # Get latest risk assessment
            latest_risk = db.execute(
                text(
                    """
                    SELECT
                        score,
                        risk_level,
                        risk_type,
                        calculated_at
                    FROM risk_scores
                    WHERE user_id = :user_id
                    ORDER BY calculated_at DESC
                    LIMIT 1
                    """
                ),
                {"user_id": patient_id},
            ).mappings().first()

            # Convert vitals_stats Row to dict
            vitals_dict = dict(vitals_stats) if vitals_stats else {}

            return HealthReportResponse(
                vitals_24h_avg=vitals_dict,
                latest_risk_score=float(latest_risk["score"]) if latest_risk and latest_risk["score"] else None,
                risk_level=latest_risk["risk_level"] if latest_risk else None,
                risk_type=latest_risk["risk_type"] if latest_risk else None,
                last_updated=latest_risk["calculated_at"] if latest_risk else None,
            )
        except Exception:
            # Return empty report on error
            return HealthReportResponse()

    @staticmethod
    def get_risk_reports(patient_id: int, db: Session, limit: int = 10) -> list[RiskReportResponse]:
        """
        Get recent risk reports/scores for the user.
        """
        try:
            rows = db.execute(
                text(
                    """
                    SELECT
                        id,
                        risk_type,
                        score,
                        risk_level,
                        calculated_at,
                        features
                    FROM risk_scores
                    WHERE user_id = :user_id
                    ORDER BY calculated_at DESC
                    LIMIT :limit
                    """
                ),
                {"user_id": patient_id, "limit": limit},
            ).mappings().all()

            reports = []
            for row in rows:
                features = row.get("features", {})
                if isinstance(features, str):
                    try:
                        features = json.loads(features)
                    except json.JSONDecodeError:
                        features = {}

                reports.append(
                    RiskReportResponse(
                        id=row["id"],
                        risk_type=row["risk_type"],
                        score=float(row["score"]),
                        risk_level=row["risk_level"],
                        timestamp=row["calculated_at"],
                        key_features=list(features.keys()) if features else [],
                    )
                )
            return reports
        except ProgrammingError:
            return []

    @staticmethod
    def get_risk_report_detail(report_id: int, db: Session) -> RiskReportDetailResponse | None:
        """
        Get detailed risk report with explanation and recommendations.
        """
        try:
            # Get risk score
            risk_row = db.execute(
                text(
                    """
                    SELECT
                        id,
                        risk_type,
                        score,
                        risk_level,
                        calculated_at,
                        features,
                        model_version,
                        algorithm
                    FROM risk_scores
                    WHERE id = :report_id
                    """
                ),
                {"report_id": report_id},
            ).mappings().first()

            if not risk_row:
                return None

            # Get explanation
            explanation_row = db.execute(
                text(
                    """
                    SELECT
                        explanation_text,
                        feature_importance,
                        recommendations
                    FROM risk_explanations
                    WHERE risk_score_id = :risk_score_id
                    LIMIT 1
                    """
                ),
                {"risk_score_id": report_id},
            ).mappings().first()

            features = risk_row.get("features", {})
            if isinstance(features, str):
                try:
                    features = json.loads(features)
                except json.JSONDecodeError:
                    features = {}

            feature_importance = {}
            recommendations = []
            explanation_text = ""

            if explanation_row:
                explanation_text = explanation_row.get("explanation_text", "")
                feature_importance = explanation_row.get("feature_importance", {})
                if isinstance(feature_importance, str):
                    try:
                        feature_importance = json.loads(feature_importance)
                    except json.JSONDecodeError:
                        feature_importance = {}

                recs = explanation_row.get("recommendations", [])
                if isinstance(recs, str):
                    try:
                        recommendations = json.loads(recs)
                    except json.JSONDecodeError:
                        recommendations = []
                else:
                    recommendations = list(recs) if recs else []

            return RiskReportDetailResponse(
                id=risk_row["id"],
                risk_type=risk_row["risk_type"],
                score=float(risk_row["score"]),
                risk_level=risk_row["risk_level"],
                timestamp=risk_row["calculated_at"],
                explanation=explanation_text,
                features=features,
                feature_importance=feature_importance,
                recommendations=recommendations,
                model_version=risk_row.get("model_version", "1.0"),
                algorithm=risk_row.get("algorithm", "unknown"),
            )
        except ProgrammingError:
            return None

    @staticmethod
    def get_risk_history(patient_id: int, db: Session, days: int = 30) -> dict:
        """
        Get risk score history over time (for charts/graphs).
        Returns daily aggregated statistics.
        """
        try:
            rows = db.execute(
                text(
                    """
                    SELECT
                        DATE(calculated_at) as date,
                        risk_type,
                        ROUND(AVG(score)::numeric, 2) as avg_score,
                        MAX(score) as max_score,
                        MIN(score) as min_score,
                        COUNT(*) as count
                    FROM risk_scores
                    WHERE user_id = :user_id
                    AND calculated_at > NOW() - INTERVAL :days || ' days'
                    GROUP BY DATE(calculated_at), risk_type
                    ORDER BY date DESC, risk_type
                    """
                ),
                {"user_id": patient_id, "days": days},
            ).mappings().all()

            # Organize by risk type
            history = {}
            for row in rows:
                risk_type = row["risk_type"]
                if risk_type not in history:
                    history[risk_type] = []

                history[risk_type].append({
                    "date": row["date"].isoformat(),
                    "avg_score": float(row["avg_score"]),
                    "max_score": float(row["max_score"]),
                    "min_score": float(row["min_score"]),
                    "measurements": row["count"],
                })

            return history
        except ProgrammingError:
            return {}
