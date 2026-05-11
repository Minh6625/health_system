"""One-shot probe for the alerts_alert_type_check CHECK constraint."""
from __future__ import annotations
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from sqlalchemy import text  # noqa: E402
from app.db.database import engine  # noqa: E402

with engine.connect() as conn:
    rows = conn.execute(
        text(
            "SELECT pg_get_constraintdef(oid) "
            "FROM pg_constraint WHERE conname = 'alerts_alert_type_check'"
        )
    ).all()
    if not rows:
        print("(no constraint found by that name — column may be unconstrained)")
    for r in rows:
        print(r[0])

    # Also dump distinct alert_type values currently in the table.
    print("\n=== distinct alert_type values currently present ===")
    for r in conn.execute(
        text("SELECT DISTINCT alert_type FROM alerts ORDER BY alert_type")
    ).all():
        print(f"  {r[0]}")
