"""Single-source-of-truth threshold loader.

Reads ``backend/app/data/rules_config.json`` (snapshot of the IoT
simulator ``pre_model_trigger/health_rules/rules_config.json``) and
projects the JSON tree into a flat threshold dict that the BE risk
pipeline + the mobile UI can consume verbatim.

Why a snapshot instead of a relative import:
- The mobile BE deploys independently of the simulator repo (Procfile +
  Heroku); we cannot rely on a sibling directory at runtime.
- The simulator's ``rules_config.json`` is the canonical authority
  (clinical rules pinned by the team). Treating it as a versioned data
  asset keeps both sides aligned without coupling deploy units.
- Refresh policy: copy the file when the simulator config bumps
  ``version`` (currently ``2.0.0``) and bump :data:`SNAPSHOT_VERSION`.

Cache strategy: in-process dict keyed by file mtime so a hot-reload
during development picks up edits without restarting uvicorn. Production
deploys read once at startup (mtime stays the same).
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from threading import Lock
from typing import Any

logger = logging.getLogger(__name__)

# Snapshot located under app/data/ so it ships with the wheel/sdist.
_SNAPSHOT_PATH: Path = Path(__file__).resolve().parent.parent / "data" / "rules_config.json"

#: Bump when the snapshot file is refreshed from the simulator repo so
#: ops can correlate "which clinical rules version is live" via the
#: ``GET /api/v1/mobile/settings/thresholds`` response.
SNAPSHOT_VERSION: str = "2.0.0"


class _Cache:
    """mtime-keyed cache for the parsed rules_config document."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._mtime: float | None = None
        self._doc: dict[str, Any] | None = None

    def get(self) -> dict[str, Any]:
        with self._lock:
            try:
                stat = _SNAPSHOT_PATH.stat()
            except FileNotFoundError:
                logger.error(
                    "rules_config snapshot missing at %s — falling back to empty doc",
                    _SNAPSHOT_PATH,
                )
                return {}
            if self._doc is not None and self._mtime == stat.st_mtime:
                return self._doc
            try:
                with _SNAPSHOT_PATH.open(encoding="utf-8-sig") as fh:
                    parsed = json.load(fh)
            except (OSError, json.JSONDecodeError) as exc:
                logger.error("Failed to parse rules_config snapshot: %s", exc)
                return self._doc or {}
            if not isinstance(parsed, dict):
                logger.error("rules_config root must be an object, got %r", type(parsed))
                return self._doc or {}
            self._doc = parsed
            self._mtime = stat.st_mtime
            return self._doc


_CACHE = _Cache()


# ---------------------------------------------------------------------------
# Vital threshold projection
# ---------------------------------------------------------------------------

#: Each entry: ``(metric_name, severity, condition_token, output_key)``.
#: Severity order ``urgent`` (most severe) > ``send_to_risk_model`` >
#: ``watch``. The condition token is a substring we match against the
#: rule's ``condition`` string. We deliberately keep this projection
#: explicit instead of trying to parse the natural-language condition
#: language from rules_config — the condition strings exist for human
#: review, the projection table here is what the API contract returns.
_VITALS_PROJECTION: list[tuple[str, str, str, str]] = [
    # Heart rate (bpm)
    ("heart_rate", "urgent", "heart_rate <= 40", "heart_rate.urgent_low"),
    ("heart_rate", "urgent", "heart_rate >= 131", "heart_rate.urgent_high"),
    ("heart_rate", "send_to_risk_model", "heart_rate <= 50", "heart_rate.send_low"),
    ("heart_rate", "send_to_risk_model", "heart_rate <= 130", "heart_rate.send_high"),
    ("heart_rate", "watch", "heart_rate <= 110", "heart_rate.watch_high"),
    # SpO2 (%)
    ("spo2", "urgent", "spo2 < 90", "spo2.urgent_low"),
    ("spo2", "send_to_risk_model", "spo2 <= 94", "spo2.send_low"),
    ("spo2", "watch", "spo2 == 95", "spo2.watch_low"),
    # Body temperature (°C)
    ("body_temp", "urgent", "body_temp <= 35.0", "body_temp.urgent_low"),
    ("body_temp", "urgent", "body_temp >= 39.1", "body_temp.urgent_high"),
    ("body_temp", "send_to_risk_model", "body_temp <= 36.0", "body_temp.send_low"),
    ("body_temp", "send_to_risk_model", "body_temp <= 39.0", "body_temp.send_high"),
    ("body_temp", "watch", "body_temp < 38.0", "body_temp.watch_high"),
    # Respiratory rate
    ("resp_rate", "urgent", "resp_rate <= 8", "resp_rate.urgent_low"),
    ("resp_rate", "urgent", "resp_rate >= 25", "resp_rate.urgent_high"),
    ("resp_rate", "send_to_risk_model", "resp_rate <= 24", "resp_rate.send_high"),
    ("resp_rate", "watch", "resp_rate <= 20", "resp_rate.watch_high"),
    # Systolic BP
    ("sys_bp", "urgent", "sys_bp <= 90", "sys_bp.urgent_low"),
    ("sys_bp", "urgent", "sys_bp >= 180", "sys_bp.urgent_high"),
    ("sys_bp", "send_to_risk_model", "sys_bp <= 100", "sys_bp.send_low"),
    ("sys_bp", "send_to_risk_model", "sys_bp >= 140", "sys_bp.send_high"),
    ("sys_bp", "watch", "sys_bp <= 139", "sys_bp.watch_high"),
    # Diastolic BP
    ("dia_bp", "urgent", "dia_bp >= 120", "dia_bp.urgent_high"),
    ("dia_bp", "send_to_risk_model", "dia_bp >= 90", "dia_bp.send_high"),
    ("dia_bp", "watch", "dia_bp <= 89", "dia_bp.watch_high"),
]

# Numeric override defaults used when the JSON document cannot be parsed
# (e.g. snapshot missing). Mirrors `rules_config.json` v2.0.0.
_FALLBACK_VITALS: dict[str, dict[str, float]] = {
    "heart_rate": {"urgent_low": 40, "send_low": 50, "watch_high": 110, "send_high": 130, "urgent_high": 131},
    "spo2": {"urgent_low": 90, "send_low": 94, "watch_low": 95},
    "body_temp": {"urgent_low": 35.0, "send_low": 36.0, "watch_high": 37.5, "send_high": 39.0, "urgent_high": 39.1},
    "resp_rate": {"urgent_low": 8, "watch_high": 20, "send_high": 24, "urgent_high": 25},
    "sys_bp": {"urgent_low": 90, "send_low": 100, "watch_high": 139, "send_high": 140, "urgent_high": 180},
    "dia_bp": {"watch_high": 89, "send_high": 90, "urgent_high": 120},
}


def _extract_threshold_from_condition(condition: str) -> float | None:
    """Pull the trailing numeric threshold from a condition string.

    Handles both shapes used in rules_config:
    - ``"heart_rate <= 40"``  -> 40
    - ``"41 <= heart_rate and heart_rate <= 50"`` -> 50 (last number)
    - ``"heart_rate >= 131"`` -> 131
    """
    import re

    # Find all integer/float numbers in the string and return the LAST one
    # because patterns like "41 <= heart_rate and heart_rate <= 50" need
    # the upper bound (50). Single-comparison rules trivially work too.
    matches = re.findall(r"-?\d+(?:\.\d+)?", condition)
    if not matches:
        return None
    try:
        return float(matches[-1])
    except (TypeError, ValueError):
        return None


def _project_vital_thresholds(doc: dict[str, Any]) -> dict[str, dict[str, float]]:
    """Walk ``instant_rules`` and build the flat ``{metric: {key: value}}`` map."""
    instant = doc.get("instant_rules") or {}
    out: dict[str, dict[str, float]] = {m: {} for m in _FALLBACK_VITALS}

    for metric, severity, cond_token, output_key in _VITALS_PROJECTION:
        metric_block = instant.get(metric) or {}
        rules: list[dict[str, Any]] = metric_block.get(severity) or []
        for rule in rules:
            cond = str(rule.get("condition") or "")
            if cond_token not in cond:
                continue
            value = _extract_threshold_from_condition(cond)
            if value is None:
                continue
            _, leaf = output_key.split(".", 1)
            out[metric][leaf] = value
            break

    # Backfill any missing leaf with the fallback so consumers never see
    # ``KeyError`` even with a partial rules document.
    for metric, defaults in _FALLBACK_VITALS.items():
        for leaf, default_value in defaults.items():
            out[metric].setdefault(leaf, default_value)
    return out


def get_vital_thresholds() -> dict[str, dict[str, float]]:
    """Public API: flat ``{metric: {leaf: value}}`` for /settings/thresholds."""
    return _project_vital_thresholds(_CACHE.get())


def get_rules_version() -> str:
    """Return ``rules_config.json::version`` or ``SNAPSHOT_VERSION`` fallback."""
    doc = _CACHE.get()
    raw = doc.get("version")
    return str(raw) if isinstance(raw, str) and raw else SNAPSHOT_VERSION


# ---------------------------------------------------------------------------
# Adapter for legacy SettingsService (DB-backed daytime/sleep dicts)
# ---------------------------------------------------------------------------

def to_legacy_daytime_dict() -> dict[str, Any]:
    """Project rules_config thresholds into the legacy ``_DEFAULT_DAYTIME`` shape.

    Keeps existing consumers in ``risk_alert_service`` /
    ``monitoring_service`` working without a behavioural change while
    they migrate to :func:`get_vital_thresholds`.
    """
    v = get_vital_thresholds()
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


def to_legacy_sleep_dict() -> dict[str, Any]:
    """Sleep-context overlay. Keeps the apnea/OSA-specific keys distinct.

    Sleep thresholds are **not** in ``rules_config.json`` (the simulator
    stores them under ``context_policy.sleep`` qualitatively only), so we
    keep the historical numeric defaults for the apnea/OSA gate but
    align the shared HR/SpO2/RR/BP keys with the daytime projection so
    only one source of truth governs them.
    """
    daytime = to_legacy_daytime_dict()
    return {
        **daytime,
        # Sleep-only sensitivity overlays preserved from the legacy
        # ``_DEFAULT_SLEEP``:
        "hr_critical_min": 38,
        "hr_critical_max": 100,
        "hr_warning_min": 42,
        "hr_warning_max": 90,
        "spo2_critical": 85,
        "spo2_warning": 90,
        "rr_critical_min": 6,
        "bp_sys_warning": 160,
        "bp_dia_warning": 100,
        # Apnea / OSA escalation gates — sleep-context only.
        "osa_alert_spo2_threshold": 88,
        "nocturnal_tachy_hr": 120,
        "apnea_rr_threshold": 6,
    }


__all__ = [
    "SNAPSHOT_VERSION",
    "get_rules_version",
    "get_vital_thresholds",
    "to_legacy_daytime_dict",
    "to_legacy_sleep_dict",
]
