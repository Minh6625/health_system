from __future__ import annotations

from datetime import UTC, datetime, timedelta
import json
import random

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError
from sqlalchemy.orm import Session

from app.schemas.monitoring import SleepSessionResponse, VitalSignsResponse


class MonitoringService:
    """Generate near-real-time telemetry used by mobile UI screens."""

    @staticmethod
    def get_latest_vital_signs(patient_id: int) -> VitalSignsResponse:
        now = datetime.now(UTC)

        # Deterministic seed for stable values in short time windows.
        slot_seed = int(now.timestamp()) // 60
        random.seed(f"{patient_id}-{slot_seed}")

        heart_rate = round(random.uniform(62, 95), 1)
        spo2 = round(random.uniform(95.0, 99.5), 1)
        temperature = round(random.uniform(36.2, 37.2), 1)
        respiratory_rate = round(random.uniform(14, 20), 1)
        blood_pressure_sys = round(random.uniform(108, 128), 0)
        blood_pressure_dia = round(random.uniform(68, 84), 0)

        return VitalSignsResponse(
            heart_rate=heart_rate,
            spo2=spo2,
            temperature=temperature,
            respiratory_rate=respiratory_rate,
            blood_pressure_sys=blood_pressure_sys,
            blood_pressure_dia=blood_pressure_dia,
            timestamp=now,
            is_stale=False,
        )

    @staticmethod
    def get_latest_sleep_session(
        patient_id: int,
        db: Session | None = None,
    ) -> SleepSessionResponse:
        if db is not None:
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
                    row = None
                else:
                    raise

            if row is not None:
                phases_raw = row.get("phases")
                phases = {"awake": 30, "light": 180, "deep": 90, "rem": 60}

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

                return SleepSessionResponse(
                    quality_score=int(row.get("sleep_score") or 0),
                    in_bed_minutes=in_bed_minutes,
                    wake_count=int(row.get("wake_count") or 0),
                    phases=phases,
                    start_time=start_time,
                    end_time=end_time,
                )

        now = datetime.now(UTC)
        start_time = now.replace(hour=22, minute=45, second=0, microsecond=0) - timedelta(days=1)
        end_time = start_time + timedelta(hours=7, minutes=45)

        random.seed(f"sleep-{patient_id}-{start_time.date().isoformat()}")
        quality = random.randint(75, 90)
        wake_count = random.randint(0, 4)

        phases = {
            "awake": 30,
            "light": 180,
            "deep": 90,
            "rem": 60,
        }

        return SleepSessionResponse(
            quality_score=quality,
            in_bed_minutes=465,
            wake_count=wake_count,
            phases=phases,
            start_time=start_time,
            end_time=end_time,
        )
