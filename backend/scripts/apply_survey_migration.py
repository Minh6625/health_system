"""One-shot migration applier for the Fall Lab Option 3-Lite survey column.

Reads ``migrations/20260501_fall_event_survey_answers.sql`` and applies it
through SQLAlchemy using the same ``DATABASE_URL`` the live backend runs
with — no need for a ``psql`` install on the host.

Usage::

    python scripts/apply_survey_migration.py
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from sqlalchemy import text  # noqa: E402

from app.db.database import engine  # noqa: E402


SQL_PATH = REPO / "migrations" / "20260501_fall_event_survey_answers.sql"


def main() -> None:
    sql = SQL_PATH.read_text(encoding="utf-8")
    with engine.begin() as conn:
        conn.execute(text(sql))
        print(f"[migration] applied {SQL_PATH.name}")

    with engine.connect() as conn:
        verify_sql = text(
            "SELECT column_name, data_type "
            "FROM information_schema.columns "
            "WHERE table_name = 'fall_events' "
            "  AND column_name = 'survey_answers'"
        )
        row = conn.execute(verify_sql).first()
        if row is None:
            raise SystemExit("[migration] FAILED — column not found")
        print(f"[migration] verified column: {row.column_name} ({row.data_type})")


if __name__ == "__main__":
    main()
