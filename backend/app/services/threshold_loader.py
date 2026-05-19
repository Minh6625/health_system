"""Single-source-of-truth threshold loader (DB-backed).

Reads ``system_settings.clinical_rules_thresholds`` row (seeded by
``backend/migrations/20260519_seed_rules_config_thresholds.sql``) so the
admin website + mobile + simulator share one editable source.

Strategy:
- Process-wide cache with TTL (300s) to avoid hammering the DB on each
  ``GET /settings/thresholds`` request.
- Built-in defaults (snapshot of rules_config v2.0.0) used as fallback
  when the row is missing or malformed — keeps the endpoint usable
  during the very first deploy before the seed migration runs.
- Cache invalidates automatically when admin updates the row via
  ``SettingsService.upsert_setting`` (which calls ``invalidate_cache``).
"""

from __future__ import annotations

import json
import logging
from threading import Lock
from time import monotonic
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

#: Bump when the seed migration ships a new rules_config version so
#: clients can detect schema drift without a full app rebuild.
SNAPSHOT_VERSION: str = "2.0.0"

_CACHE_TTL_SECONDS: float = 300.0
_DB_KEY: str = "clinical_rules_thresholds"

_FALLBACK_DOC: dict[str, Any] = {
    "version": "2.0.0",
    "vitals": {
        "heart_rate": {
            "urgent_low": 40,
            "send_low": 50,
            "watch_high": 110,
            "send_high": 130,
            "urgent_high": 131,
        },
        "spo2": {"urgent_low": 90, "send_low": 94, "watch_low": 95},
        "body_temp": {
            "urgent_low": 35.0,
            "send_low": 36.0,
            "watch_high": 37.5,
            "send_high": 39.0,
            "urgent_high": 39.1,
        },
        "resp_rate": {
            "urgent_low": 8,
            "watch_high": 20,
            "send_high": 24,
            "urgent_high": 25,
        },
        "sys_bp": {
            "urgent_low": 90,
            "send_low": 100,
            "watch_high": 139,
            "send_high": 140,
            "urgent_high": 180,
        },
        "dia_bp": {"watch_high": 89, "send_high": 90, "urgent_high": 120},
    },
    "fall_confidence_threshold": 0.5,
    "model_thresholds": {
        "health": {"warning_at": 0.35, "high_risk_true_at": 0.5, "critical_at": 0.65},
        "fall": {"fall_true_at": 0.5, "warning_at": 0.6, "critical_at": 0.85},
        "sleep": {
            "critical_below": 50,
            "poor_below": 60,
            "fair_below": 75,
            "good_below": 85,
        },
    },
}


class _Cache:
    """TTL-keyed cache for the parsed clinical_rules_thresholds doc."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._fetched_at: float = 0.0
        self._doc: dict[str, Any] | None = None

    def get(self, db: Session | None) -> dict[str, Any]:
        """Return the doc, fetching from DB if stale (or first call)."""
        with self._lock:
            now = monotonic()
            if self._doc is not None and (now - self._fetched_at) < _CACHE_TTL_SECONDS:
                return self._doc
            doc = _read_from_db(db) if db is not None else None
            if doc is None:
                # Keep stale doc rather than fallback if we previously had a
                # successful read — only return fallback when we never fetched.
                if self._doc is not None:
                    return self._doc
                logger.warning(
                    "clinical_rules_thresholds row not found, using built-in "
                    "rules_config v2.0.0 defaults"
                )
                return _FALLBACK_DOC
            self._doc = doc
            self._fetched_at = now
            return doc

    def invalidate(self) -> None:
        with self._lock:
            self._fetched_at = 0.0
            self._doc = None


_CACHE = _Cache()


def _read_from_db(db: Session) -> dict[str, Any] | None:
    """Fetch + parse the clinical_rules_thresholds JSONB row."""
    try:
        row = db.execute(
            text(
                "SELECT setting_value FROM system_settings "
                "WHERE setting_key = :key"
            ),
            {"key": _DB_KEY},
        ).fetchone()
    except Exception as exc:  # noqa: BLE001 - log + fallback
        logger.warning("threshold_loader DB read failed: %s", exc)
        return None
    if row is None:
        return None
    raw = row[0]
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except json.JSONDecodeError as exc:
            logger.error("clinical_rules_thresholds malformed JSON: %s", exc)
            return None
    if not isinstance(raw, dict):
        logger.error("clinical_rules_thresholds is not a JSON object: %r", type(raw))
        return None
    return raw


def invalidate_cache() -> None:
    """Test/admin hook — flush in-memory cache so the next call re-reads DB."""
    _CACHE.invalidate()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def get_clinical_thresholds_doc(db: Session | None = None) -> dict[str, Any]:
    """Return the full nested rules_config document (DB-backed + cached)."""
    return _CACHE.get(db)


def get_vital_thresholds(db: Session | None = None) -> dict[str, dict[str, float]]:
    """Public API: flat ``{metric: {leaf: value}}`` for /settings/thresholds."""
    doc = _CACHE.get(db)
    vitals = doc.get("vitals") or {}
    if not isinstance(vitals, dict):
        return {k: dict(v) for k, v in (_FALLBACK_DOC["vitals"]).items()}
    out: dict[str, dict[str, float]] = {}
    for metric, default_block in _FALLBACK_DOC["vitals"].items():
        block = vitals.get(metric)
        if isinstance(block, dict):
            merged = {k: float(v) for k, v in default_block.items()}
            for leaf, value in block.items():
                try:
                    merged[leaf] = float(value)
                except (TypeError, ValueError):
                    continue
            out[metric] = merged
        else:
            out[metric] = dict(default_block)
    return out


def get_rules_version(db: Session | None = None) -> str:
    """Return ``setting_value::version`` or ``SNAPSHOT_VERSION`` fallback."""
    doc = _CACHE.get(db)
    raw = doc.get("version")
    return str(raw) if isinstance(raw, str) and raw else SNAPSHOT_VERSION


def get_fall_confidence_threshold(db: Session | None = None) -> float:
    """BE secondary-validation gate (telemetry.py)."""
    doc = _CACHE.get(db)
    raw = doc.get("fall_confidence_threshold")
    try:
        value = float(raw) if raw is not None else 0.5
    except (TypeError, ValueError):
        value = 0.5
    return max(0.0, min(1.0, value))


def get_model_thresholds(db: Session | None = None) -> dict[str, dict[str, float]]:
    """Return health/fall/sleep model bands."""
    doc = _CACHE.get(db)
    raw = doc.get("model_thresholds")
    if not isinstance(raw, dict):
        return {k: dict(v) for k, v in _FALLBACK_DOC["model_thresholds"].items()}
    out: dict[str, dict[str, float]] = {}
    for domain, default_block in _FALLBACK_DOC["model_thresholds"].items():
        block = raw.get(domain)
        if isinstance(block, dict):
            merged = {k: float(v) for k, v in default_block.items()}
            for leaf, value in block.items():
                try:
                    merged[leaf] = float(value)
                except (TypeError, ValueError):
                    continue
            out[domain] = merged
        else:
            out[domain] = dict(default_block)
    return out


# ---------------------------------------------------------------------------
# Adapter for legacy SettingsService consumers
# ---------------------------------------------------------------------------


def to_legacy_daytime_dict(db: Session | None = None) -> dict[str, Any]:
    """Project clinical thresholds into the legacy ``_DEFAULT_DAYTIME`` shape."""
    v = get_vital_thresholds(db)
    return {
        "hr_critical_min": int(v["heart_rate"]["urgent_low"]),
        "hr_critical_max": int(v["heart_rate"]["urgent_high"]),
        "hr_warning_min": int(v["heart_rate"]["send_low"]),
        "hr_warning_max": int(v["heart_rate"]["watch_high"]),
        "spo2_critical": int(v["spo2"]["urgent_low"]),
        "spo2_warning": int(v["spo2"]["send_low"]),
        "rr_critical_min": int(v["resp_rate"]["urgent_low"]),
        "rr_critical_max": int(v["resp_rate"]["urgent_high"]),
        "bp_sys_critical": int(v["sys_bp"]["urgent_high"]),
        "bp_dia_critical": int(v["dia_bp"]["urgent_high"]),
        "bp_sys_warning": int(v["sys_bp"]["send_high"]),
        "bp_dia_warning": int(v["dia_bp"]["send_high"]),
    }


def to_legacy_sleep_dict(db: Session | None = None) -> dict[str, Any]:
    """Sleep-context overlay (apnea/OSA gates kept as historical defaults)."""
    daytime = to_legacy_daytime_dict(db)
    return {
        **daytime,
        # Sleep-only overlay preserved from the legacy ``_DEFAULT_SLEEP``.
        # These remain hardcoded because rules_config does not encode sleep
        # numeric overrides — they live in DB row ``vitals_sleep_thresholds``
        # which is read separately by SettingsService.get_vitals_sleep_thresholds.
        "hr_critical_min": 38,
        "hr_critical_max": 100,
        "hr_warning_min": 42,
        "hr_warning_max": 90,
        "spo2_critical": 85,
        "spo2_warning": 90,
        "rr_critical_min": 6,
        "bp_sys_warning": 160,
        "bp_dia_warning": 100,
        "osa_alert_spo2_threshold": 88,
        "nocturnal_tachy_hr": 120,
        "apnea_rr_threshold": 6,
    }


__all__ = [
    "SNAPSHOT_VERSION",
    "get_clinical_thresholds_doc",
    "get_fall_confidence_threshold",
    "get_model_thresholds",
    "get_rules_version",
    "get_vital_thresholds",
    "invalidate_cache",
    "to_legacy_daytime_dict",
    "to_legacy_sleep_dict",
]
