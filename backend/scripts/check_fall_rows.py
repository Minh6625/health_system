"""Quick read-only probe of the latest fall_events rows."""
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
            "SELECT id, device_id, confidence, sos_triggered, "
            "sos_triggered_at, survey_answers "
            "FROM fall_events ORDER BY id DESC LIMIT 5"
        )
    ).mappings().all()
    for r in rows:
        print(
            f"fe={r['id']} dev={r['device_id']} "
            f"conf={float(r['confidence']):.3f} "
            f"sos_trig={r['sos_triggered']} "
            f"sos_at={r['sos_triggered_at']} "
            f"survey={r['survey_answers']}"
        )
