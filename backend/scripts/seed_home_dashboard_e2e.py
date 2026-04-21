from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

from sqlalchemy import create_engine, text

from app.core.config import settings
from app.utils.password import hash_password


@dataclass(frozen=True)
class SeedUser:
    email: str
    password: str
    full_name: str
    role: str
    device_name: str
    serial_number: str
    risk_series: tuple[tuple[int, int, str], ...]
    vitals: dict[str, object]
    sleep_score: int
    sleep_minutes: int
    awake_minutes: int
    wake_count: int


PATIENT = SeedUser(
    email="e2e.dashboard.patient@example.com",
    password="PatientE2E!123",
    full_name="Tran Patient E2E",
    role="user",
    device_name="E2E Patient Watch",
    serial_number="e2e-dashboard-patient-watch",
    risk_series=(
        (6, 58, "medium"),
        (4, 52, "medium"),
        (2, 47, "medium"),
        (0, 43, "medium"),
    ),
    vitals={
        "heart_rate": 104,
        "spo2": Decimal("94.0"),
        "temperature": Decimal("37.9"),
        "blood_pressure_sys": 142,
        "blood_pressure_dia": 93,
        "hrv": 31,
        "respiratory_rate": 21,
        "signal_quality": 1,
        "motion_artifact": False,
    },
    sleep_score=78,
    sleep_minutes=392,
    awake_minutes=28,
    wake_count=1,
)

CAREGIVER = SeedUser(
    email="e2e.dashboard.caregiver@example.com",
    password="CaregiverE2E!123",
    full_name="Nguyen Caregiver E2E",
    role="user",
    device_name="E2E Caregiver Watch",
    serial_number="e2e-dashboard-caregiver-watch",
    risk_series=(
        (6, 26, "low"),
        (4, 22, "low"),
        (2, 19, "low"),
        (0, 17, "low"),
    ),
    vitals={
        "heart_rate": 72,
        "spo2": Decimal("98.0"),
        "temperature": Decimal("36.7"),
        "blood_pressure_sys": 118,
        "blood_pressure_dia": 76,
        "hrv": 54,
        "respiratory_rate": 16,
        "signal_quality": 1,
        "motion_artifact": False,
    },
    sleep_score=90,
    sleep_minutes=438,
    awake_minutes=18,
    wake_count=1,
)

EMPTY_SLEEP = SeedUser(
    email="e2e.sleep.empty@example.com",
    password="SleepEmptyE2E!123",
    full_name="Sleep Empty E2E",
    role="user",
    device_name="unused-empty-sleep-watch",
    serial_number="unused-empty-sleep-watch",
    risk_series=(),
    vitals={
        "heart_rate": 72,
        "spo2": Decimal("98.0"),
        "temperature": Decimal("36.7"),
        "blood_pressure_sys": 118,
        "blood_pressure_dia": 76,
        "hrv": 54,
        "respiratory_rate": 16,
        "signal_quality": 1,
        "motion_artifact": False,
    },
    sleep_score=0,
    sleep_minutes=0,
    awake_minutes=0,
    wake_count=0,
)


def _now_utc() -> datetime:
    return datetime.now(UTC).replace(microsecond=0)


def _health_score(score: int) -> int:
    return max(0, 100 - score)


def _feature_importance(score: int) -> dict[str, float]:
    intensity = min(max(score / 100, 0.1), 0.9)
    return {
        "heart_rate": round(0.45 + intensity * 0.2, 3),
        "sys_bp": round(0.32 + intensity * 0.15, 3),
        "spo2": round(0.18 + intensity * 0.08, 3),
    }


def _feature_payload(user: SeedUser, score: int) -> dict[str, object]:
    return {
        "confidence": 0.91,
        "model_features": {
            "heart_rate": user.vitals["heart_rate"],
            "spo2": float(user.vitals["spo2"]),
            "sys_bp": user.vitals["blood_pressure_sys"],
            "dia_bp": user.vitals["blood_pressure_dia"],
            "body_temp": float(user.vitals["temperature"]),
            "resp_rate": user.vitals["respiratory_rate"],
            "hrv": user.vitals["hrv"],
            "map_val": round(
                (
                    float(user.vitals["blood_pressure_sys"])
                    + 2 * float(user.vitals["blood_pressure_dia"])
                )
                / 3,
                1,
            ),
        },
        "raw_vitals": {
            "heart_rate": user.vitals["heart_rate"],
            "spo2": float(user.vitals["spo2"]),
            "temperature": float(user.vitals["temperature"]),
            "blood_pressure_sys": user.vitals["blood_pressure_sys"],
            "blood_pressure_dia": user.vitals["blood_pressure_dia"],
            "respiratory_rate": user.vitals["respiratory_rate"],
            "hrv": user.vitals["hrv"],
        },
        "risk_score": score,
        "health_score": _health_score(score),
    }


def _sleep_phases(user: SeedUser) -> dict[str, int]:
    deep = 96 if user is PATIENT else 118
    rem = 74 if user is PATIENT else 92
    light = max(user.sleep_minutes - deep - rem, 180)
    return {
        "deep": deep,
        "light": light,
        "rem": rem,
        "awake": user.awake_minutes,
    }


def _upsert_user(connection, user: SeedUser) -> int:
    user_id = connection.execute(
        text(
            """
            INSERT INTO users (
                email,
                password_hash,
                full_name,
                role,
                is_active,
                is_verified
            )
            VALUES (
                :email,
                :password_hash,
                :full_name,
                :role,
                TRUE,
                TRUE
            )
            ON CONFLICT (email) DO UPDATE SET
                password_hash = EXCLUDED.password_hash,
                full_name = EXCLUDED.full_name,
                role = EXCLUDED.role,
                is_active = TRUE,
                is_verified = TRUE,
                deleted_at = NULL
            RETURNING id
            """
        ),
        {
            "email": user.email,
            "password_hash": hash_password(user.password),
            "full_name": user.full_name,
            "role": user.role,
        },
    ).scalar_one()
    return int(user_id)


def _reset_user_data(connection, user_id: int) -> None:
    device_ids = [
        int(row[0])
        for row in connection.execute(
            text("SELECT id FROM devices WHERE user_id = :user_id"),
            {"user_id": user_id},
        ).fetchall()
    ]
    if device_ids:
        connection.execute(
            text("DELETE FROM vitals WHERE device_id = ANY(:device_ids)"),
            {"device_ids": device_ids},
        )
        connection.execute(
            text("DELETE FROM sleep_sessions WHERE device_id = ANY(:device_ids)"),
            {"device_ids": device_ids},
        )
        connection.execute(
            text("DELETE FROM risk_scores WHERE device_id = ANY(:device_ids)"),
            {"device_ids": device_ids},
        )
    risk_ids = [
        int(row[0])
        for row in connection.execute(
            text("SELECT id FROM risk_scores WHERE user_id = :user_id"),
            {"user_id": user_id},
        ).fetchall()
    ]
    if risk_ids:
        connection.execute(
            text("DELETE FROM risk_explanations WHERE risk_score_id = ANY(:risk_ids)"),
            {"risk_ids": risk_ids},
        )
    connection.execute(
        text("DELETE FROM risk_scores WHERE user_id = :user_id"),
        {"user_id": user_id},
    )
    connection.execute(
        text("DELETE FROM devices WHERE user_id = :user_id"),
        {"user_id": user_id},
    )


def _create_device(connection, user_id: int, user: SeedUser) -> int:
    device_id = connection.execute(
        text(
            """
            INSERT INTO devices (
                user_id,
                device_name,
                device_type,
                serial_number,
                is_active,
                battery_level,
                last_seen_at,
                last_sync_at
            )
            VALUES (
                :user_id,
                :device_name,
                'smartwatch',
                :serial_number,
                TRUE,
                82,
                :now_at,
                :now_at
            )
            RETURNING id
            """
        ),
        {
            "user_id": user_id,
            "device_name": user.device_name,
            "serial_number": user.serial_number,
            "now_at": _now_utc(),
        },
    ).scalar_one()
    return int(device_id)


def _seed_latest_vitals(connection, device_id: int, user: SeedUser) -> None:
    emitted_at = _now_utc() - timedelta(seconds=45)
    connection.execute(
        text(
            """
            INSERT INTO vitals (
                time,
                device_id,
                heart_rate,
                spo2,
                temperature,
                blood_pressure_sys,
                blood_pressure_dia,
                hrv,
                respiratory_rate,
                signal_quality,
                motion_artifact
            )
            VALUES (
                :time,
                :device_id,
                :heart_rate,
                :spo2,
                :temperature,
                :blood_pressure_sys,
                :blood_pressure_dia,
                :hrv,
                :respiratory_rate,
                :signal_quality,
                :motion_artifact
            )
            """
        ),
        {"time": emitted_at, "device_id": device_id, **user.vitals},
    )


def _seed_sleep_session(connection, user_id: int, device_id: int, user: SeedUser) -> None:
    end_time = _now_utc() - timedelta(hours=1)
    start_time = end_time - timedelta(minutes=user.sleep_minutes + user.awake_minutes)
    connection.execute(
        text(
            """
            INSERT INTO sleep_sessions (
                user_id,
                device_id,
                start_time,
                end_time,
                sleep_score,
                phases,
                wake_count,
                sleep_date
            )
            VALUES (
                :user_id,
                :device_id,
                :start_time,
                :end_time,
                :sleep_score,
                CAST(:phases AS jsonb),
                :wake_count,
                :sleep_date
            )
            """
        ),
        {
            "user_id": user_id,
            "device_id": device_id,
            "start_time": start_time,
            "end_time": end_time,
            "sleep_score": user.sleep_score,
            "phases": json.dumps(_sleep_phases(user)),
            "wake_count": user.wake_count,
            "sleep_date": date.today(),
        },
    )


def _seed_risk_reports(connection, user_id: int, device_id: int, user: SeedUser) -> None:
    latest_importance: dict[str, float] | None = None
    latest_score_id = None
    for days_ago, score, level in user.risk_series:
        calculated_at = _now_utc() - timedelta(days=days_ago, minutes=12)
        importance = _feature_importance(score)
        risk_score_id = connection.execute(
            text(
                """
                INSERT INTO risk_scores (
                    user_id,
                    device_id,
                    calculated_at,
                    risk_type,
                    score,
                    risk_level,
                    features,
                    model_version,
                    algorithm
                )
                VALUES (
                    :user_id,
                    :device_id,
                    :calculated_at,
                    'general',
                    :score,
                    :risk_level,
                    CAST(:features AS jsonb),
                    'e2e-v1',
                    'xgb'
                )
                RETURNING id
                """
            ),
            {
                "user_id": user_id,
                "device_id": device_id,
                "calculated_at": calculated_at,
                "score": Decimal(str(score)),
                "risk_level": level,
                "features": json.dumps(_feature_payload(user, score)),
            },
        ).scalar_one()
        connection.execute(
            text(
                """
                INSERT INTO risk_explanations (
                    risk_score_id,
                    explanation_text,
                    feature_importance,
                    xai_method,
                    recommendations
                )
                VALUES (
                    :risk_score_id,
                    :explanation_text,
                    CAST(:feature_importance AS jsonb),
                    'rule_based',
                    :recommendations
                )
                """
            ),
            {
                "risk_score_id": int(risk_score_id),
                "explanation_text": (
                    f"{user.full_name} co dau hieu can theo doi nhip tim, SpO2 va huyet ap "
                    f"trong danh gia {score}/100."
                ),
                "feature_importance": json.dumps(importance),
                "recommendations": [
                    "Do lai chi so sau khi nghi ngoi 5 phut",
                    "Theo doi giac ngu va uong du nuoc",
                    "Lien he bac si neu trieu chung tang len",
                ],
            },
        )
        latest_importance = importance
        latest_score_id = int(risk_score_id)

    if latest_score_id is None or latest_importance is None:
        raise RuntimeError(f"Risk seed failed for {user.email}")


def _seed_relationships(connection, patient_id: int, caregiver_id: int) -> None:
    connection.execute(
        text(
            """
            DELETE FROM user_relationships
            WHERE (patient_id = :patient_id AND caregiver_id = :caregiver_id)
               OR (patient_id = :caregiver_id AND caregiver_id = :patient_id)
            """
        ),
        {"patient_id": patient_id, "caregiver_id": caregiver_id},
    )

    shared_tags = json.dumps([{"id": "family", "name": "Gia dinh"}])
    now_at = _now_utc()
    connection.execute(
        text(
            """
            INSERT INTO user_relationships (
                patient_id,
                caregiver_id,
                relationship_type,
                status,
                primary_relationship_label,
                tags,
                can_view_vitals,
                can_receive_alerts,
                can_view_location,
                created_at
            )
            VALUES
                (
                    :patient_id,
                    :caregiver_id,
                    'family',
                    'accepted',
                    'Cha',
                    CAST(:tags AS json),
                    TRUE,
                    TRUE,
                    FALSE,
                    :created_at
                ),
                (
                    :caregiver_id,
                    :patient_id,
                    'family',
                    'accepted',
                    'Con',
                    CAST(:tags AS json),
                    TRUE,
                    TRUE,
                    FALSE,
                    :created_at
                )
            """
        ),
        {
            "patient_id": patient_id,
            "caregiver_id": caregiver_id,
            "tags": shared_tags,
            "created_at": now_at,
        },
    )


def main() -> None:
    engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    try:
        with engine.begin() as connection:
            patient_id = _upsert_user(connection, PATIENT)
            caregiver_id = _upsert_user(connection, CAREGIVER)
            empty_sleep_id = _upsert_user(connection, EMPTY_SLEEP)

            _reset_user_data(connection, patient_id)
            _reset_user_data(connection, caregiver_id)
            _reset_user_data(connection, empty_sleep_id)

            patient_device_id = _create_device(connection, patient_id, PATIENT)
            caregiver_device_id = _create_device(connection, caregiver_id, CAREGIVER)

            _seed_latest_vitals(connection, patient_device_id, PATIENT)
            _seed_latest_vitals(connection, caregiver_device_id, CAREGIVER)

            _seed_sleep_session(connection, patient_id, patient_device_id, PATIENT)
            _seed_sleep_session(connection, caregiver_id, caregiver_device_id, CAREGIVER)

            _seed_risk_reports(connection, patient_id, patient_device_id, PATIENT)
            _seed_risk_reports(connection, caregiver_id, caregiver_device_id, CAREGIVER)

            _seed_relationships(connection, patient_id, caregiver_id)

        summary = {
            "patient": {
                "email": PATIENT.email,
                "password": PATIENT.password,
                "user_id": patient_id,
            },
            "caregiver": {
                "email": CAREGIVER.email,
                "password": CAREGIVER.password,
                "user_id": caregiver_id,
            },
            "empty_sleep": {
                "email": EMPTY_SLEEP.email,
                "password": EMPTY_SLEEP.password,
                "user_id": empty_sleep_id,
            },
        }
        print(json.dumps(summary, ensure_ascii=True, indent=2))
    finally:
        engine.dispose()


if __name__ == "__main__":
    main()
