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
