"""Seed clinical thresholds into system_settings.

Runs the SQL migration ``20260519_seed_rules_config_thresholds.sql`` so
the DB has the canonical rules_config v2.0.0 row that
``GET /api/v1/mobile/settings/thresholds`` serves.

Usage::

    cd backend
    python scripts/seed_thresholds.py

Idempotent — uses ``ON CONFLICT DO UPDATE`` so re-running after manual
edits via the admin website overrides the row back to the pinned
defaults. Run again only when you genuinely want to reset.
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

# Make ``app`` importable regardless of cwd.
_BACKEND_ROOT = Path(__file__).resolve().parent.parent
if str(_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKEND_ROOT))

from sqlalchemy import text  # noqa: E402

from app.db.database import engine  # noqa: E402
from app.services.threshold_loader import invalidate_cache  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(levelname)-8s %(message)s")
logger = logging.getLogger(__name__)

_MIGRATION_FILE = (
    _BACKEND_ROOT / "migrations" / "20260519_seed_rules_config_thresholds.sql"
)


def main() -> int:
    if not _MIGRATION_FILE.exists():
        logger.error("migration file not found: %s", _MIGRATION_FILE)
        return 1

    sql = _MIGRATION_FILE.read_text(encoding="utf-8")

    with engine.begin() as conn:
        conn.execute(text(sql))

    invalidate_cache()
    logger.info("seeded clinical_rules_thresholds + vitals_default_thresholds + vitals_sleep_thresholds")

    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT setting_key, setting_value->>'version' AS v "
                "FROM system_settings "
                "WHERE setting_key IN ("
                "'clinical_rules_thresholds','vitals_default_thresholds','vitals_sleep_thresholds')"
                " ORDER BY setting_key"
            )
        ).fetchall()
    for r in rows:
        logger.info("  %-30s version=%s", r[0], r[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
