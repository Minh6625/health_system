from __future__ import annotations

import json
import logging
from time import monotonic
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

_CACHE_TTL_SEC = 300.0

_DEFAULT_DAYTIME: dict[str, Any] = {
    "hr_critical_min": 50,
    "hr_critical_max": 120,
    "hr_warning_min": 55,
    "hr_warning_max": 110,
    "spo2_critical": 90,
    "spo2_warning": 94,
    "rr_critical_min": 10,
    "rr_critical_max": 25,
    "bp_sys_critical": 180,
    "bp_dia_critical": 120,
    "bp_sys_warning": 140,
    "bp_dia_warning": 90,
}

_DEFAULT_SLEEP: dict[str, Any] = {
    "hr_critical_min": 38,
    "hr_critical_max": 100,
    "hr_warning_min": 42,
    "hr_warning_max": 90,
    "spo2_critical": 85,
    "spo2_warning": 90,
    "rr_critical_min": 6,
    "rr_critical_max": 25,
    "bp_sys_critical": 180,
    "bp_dia_critical": 120,
    "bp_sys_warning": 160,
    "bp_dia_warning": 100,
    "osa_alert_spo2_threshold": 88,
    "nocturnal_tachy_hr": 120,
    "apnea_rr_threshold": 6,
}

_THRESHOLD_KEY_ALIASES: dict[str, str] = {
    "hr_min": "hr_critical_min",
    "hr_max": "hr_critical_max",
    "bp_dis_critical": "bp_dia_critical",
    "bp_dis_warning": "bp_dia_warning",
}


class SettingsService:
    _cache: dict[str, tuple[float, Any]] = {}

    @classmethod
    def get_setting(cls, key: str, db: Session, default: Any = None) -> Any:
        now = monotonic()
        cached = cls._cache.get(key)
        if cached is not None and (now - cached[0]) < _CACHE_TTL_SEC:
            return cached[1]
        try:
            row = db.execute(
                text("SELECT setting_value FROM system_settings WHERE setting_key = :key"),
                {"key": key},
            ).fetchone()
            value = row[0] if row is not None else default
            if isinstance(value, str):
                stripped = value.strip()
                if stripped.startswith("{") or stripped.startswith("["):
                    value = json.loads(value)
            cls._cache[key] = (now, value)
            return value
        except Exception as exc:
            logger.warning("SettingsService read failed for key=%s: %s", key, exc)
            return default

    @classmethod
    def get_vitals_sleep_thresholds(cls, db: Session) -> dict[str, Any]:
        result = cls.get_setting("vitals_sleep_thresholds", db, _DEFAULT_SLEEP)
        return cls._normalize_thresholds(result, _DEFAULT_SLEEP)

    @classmethod
    def get_vitals_daytime_thresholds(cls, db: Session) -> dict[str, Any]:
        result = cls.get_setting("vitals_default_thresholds", db, _DEFAULT_DAYTIME)
        return cls._normalize_thresholds(result, _DEFAULT_DAYTIME)

    @classmethod
    def upsert_setting(
        cls,
        db: Session,
        *,
        key: str,
        value: Any,
        group: str,
        description: str,
        updated_by: int | None = None,
        is_editable: bool = True,
    ) -> None:
        payload = json.dumps(value)
        db.execute(
            text(
                """
                INSERT INTO system_settings (
                    setting_key,
                    setting_group,
                    setting_value,
                    description,
                    is_editable,
                    updated_by
                )
                VALUES (
                    :setting_key,
                    :setting_group,
                    CAST(:setting_value AS jsonb),
                    :description,
                    :is_editable,
                    :updated_by
                )
                ON CONFLICT (setting_key)
                DO UPDATE SET
                    setting_group = EXCLUDED.setting_group,
                    setting_value = EXCLUDED.setting_value,
                    description = EXCLUDED.description,
                    is_editable = EXCLUDED.is_editable,
                    updated_by = EXCLUDED.updated_by,
                    updated_at = NOW()
                """
            ),
            {
                "setting_key": key,
                "setting_group": group,
                "setting_value": payload,
                "description": description,
                "is_editable": is_editable,
                "updated_by": updated_by,
            },
        )
        db.commit()
        cls.invalidate_cache(key)

    @classmethod
    def get_general_settings(cls, db: Session) -> dict[str, Any]:
        language = cls.get_setting("app_language", db, "vi")
        theme = cls.get_setting("app_theme", db, "system")
        timezone = cls.get_setting("default_timezone", db, "Asia/Ho_Chi_Minh")

        gateways = cls.get_setting("notification_gateways", db, {"push_enabled": True})
        if not isinstance(gateways, dict):
            gateways = {"push_enabled": bool(gateways)}
        push_enabled = bool(gateways.get("push_enabled", True))

        maintenance_scalar = cls.get_setting("maintenance_mode", db, None)
        system_security = cls.get_setting(
            "system_security",
            db,
            {"maintenance_mode": False, "session_timeout_minutes": 60},
        )
        if not isinstance(system_security, dict):
            system_security = {"maintenance_mode": False, "session_timeout_minutes": 60}

        jwt_expiry_minutes = cls.get_setting("jwt_access_expiry_minutes", db, None)
        session_timeout = int(
            jwt_expiry_minutes
            if isinstance(jwt_expiry_minutes, (int, float))
            else system_security.get("session_timeout_minutes", 60)
        )

        maintenance_mode = bool(
            maintenance_scalar
            if isinstance(maintenance_scalar, bool)
            else system_security.get("maintenance_mode", False)
        )

        return {
            "language": str(language),
            "theme": str(theme),
            "timezone": str(timezone),
            "push_notifications_enabled": push_enabled,
            "maintenance_mode": maintenance_mode,
            "session_timeout_minutes": session_timeout,
        }

    @classmethod
    def update_general_settings(
        cls,
        db: Session,
        *,
        user_id: int,
        language: str | None = None,
        theme: str | None = None,
        timezone: str | None = None,
        push_notifications_enabled: bool | None = None,
        maintenance_mode: bool | None = None,
        session_timeout_minutes: int | None = None,
    ) -> dict[str, Any]:
        if language is not None:
            cls.upsert_setting(
                db,
                key="app_language",
                value=language,
                group="ui",
                description="Ngon ngu giao dien mobile app",
                updated_by=user_id,
            )

        if theme is not None:
            cls.upsert_setting(
                db,
                key="app_theme",
                value=theme,
                group="ui",
                description="Che do giao dien mobile app",
                updated_by=user_id,
            )

        if timezone is not None:
            cls.upsert_setting(
                db,
                key="default_timezone",
                value=timezone,
                group="infra",
                description="Mui gio mac dinh cho app",
                updated_by=user_id,
            )

        if push_notifications_enabled is not None:
            gateways = cls.get_setting("notification_gateways", db, {"push_enabled": True})
            if not isinstance(gateways, dict):
                gateways = {}
            gateways["push_enabled"] = bool(push_notifications_enabled)
            cls.upsert_setting(
                db,
                key="notification_gateways",
                value=gateways,
                group="infra",
                description="Cau hinh kenh thong bao",
                updated_by=user_id,
            )

        if maintenance_mode is not None:
            cls.upsert_setting(
                db,
                key="maintenance_mode",
                value=bool(maintenance_mode),
                group="security",
                description="Maintenance mode cho mobile app",
                updated_by=user_id,
            )

            system_security = cls.get_setting(
                "system_security",
                db,
                {"maintenance_mode": False, "session_timeout_minutes": 60},
            )
            if not isinstance(system_security, dict):
                system_security = {}
            system_security["maintenance_mode"] = bool(maintenance_mode)
            cls.upsert_setting(
                db,
                key="system_security",
                value=system_security,
                group="security",
                description="Cau hinh bao mat he thong",
                updated_by=user_id,
            )

        if session_timeout_minutes is not None:
            cls.upsert_setting(
                db,
                key="jwt_access_expiry_minutes",
                value=int(session_timeout_minutes),
                group="security",
                description="Thoi gian het han session (phut)",
                updated_by=user_id,
            )

            system_security = cls.get_setting(
                "system_security",
                db,
                {"maintenance_mode": False, "session_timeout_minutes": 60},
            )
            if not isinstance(system_security, dict):
                system_security = {}
            system_security["session_timeout_minutes"] = int(session_timeout_minutes)
            cls.upsert_setting(
                db,
                key="system_security",
                value=system_security,
                group="security",
                description="Cau hinh bao mat he thong",
                updated_by=user_id,
            )

        return cls.get_general_settings(db)

    @classmethod
    def invalidate_cache(cls, key: str | None = None) -> None:
        if key is None:
            cls._cache.clear()
            return
        cls._cache.pop(key, None)

    @staticmethod
    def _normalize_thresholds(value: Any, fallback: dict[str, Any]) -> dict[str, Any]:
        normalized = dict(fallback)
        if not isinstance(value, dict):
            return normalized
        for key, raw in value.items():
            target_key = _THRESHOLD_KEY_ALIASES.get(key, key)
            normalized[target_key] = raw
        return normalized
