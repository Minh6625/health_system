"""ETL: UP-Fall Detection Dataset CSVs -> labelled FallPredictionRequest JSONL.

The UP-Fall dataset (Casilari et al., 2017) ships in the simulator
repository under ``Iot_Simulator_clean/datasets/05_fall/UP-Fall/``.
This module walks the raw CSVs and produces a deterministic JSONL
fixture that the gated confusion-matrix harness consumes.

Activity taxonomy (per the dataset README):

| Code | Activity | Class |
|------|---|---|
| A01 | Falling forward using hands | FALL |
| A02 | Falling forward using knees | FALL |
| A03 | Falling backwards | FALL |
| A04 | Falling sideward | FALL |
| A05 | Falling sitting in empty chair | FALL |
| A06 | Walking | ADL |
| A07 | Standing | ADL |
| A08 | Sitting | ADL |
| A09 | Picking up an object | ADL |
| A10 | Jumping | ADL |
| A11 | Laying | ADL |

For each (subject, activity, trial) CSV we:

1. Parse the BELT IMU columns (``BELT_ACC_*`` accelerometer,
   ``BELT_ANG_*`` gyroscope angular velocity).
2. Find the index of peak acceleration magnitude.
3. Extract a 50-sample window centred on the peak (clamped to trial
   bounds). Trials with fewer than 50 samples are skipped — too short
   for the model-api ``fall_min_sequence_samples=50`` requirement.
4. Derive pitch / roll from gravity vector projection on the accel
   readings (yaw=0 — UP-Fall has no magnetometer). Environment fields
   default to zero (the dataset has none).
5. Emit one JSONL line: ``{"label": bool, "request": {...}}`` where
   ``request`` is a fully-valid ``FallPredictionRequest`` body.

Run:

```bash
cd backend
python -m tests.eval.etl_up_fall
```

The output ``fixtures/up_fall_windows.jsonl`` is checked into git so
the harness is reproducible without re-running the ETL on every CI
run. Re-run only when the dataset itself changes.
"""

from __future__ import annotations

import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

#: Activities we treat as positive class (falls).
FALL_ACTIVITY_CODES: frozenset[str] = frozenset({"A01", "A02", "A03", "A04", "A05"})

#: Activities we treat as negative class (activities of daily living).
ADL_ACTIVITY_CODES: frozenset[str] = frozenset({"A06", "A07", "A08", "A09", "A10", "A11"})

#: Window size required by the model-api ``fall_min_sequence_samples`` setting.
WINDOW_SIZE: int = 50

#: Sampling rate declared on the request — the source dataset's TIME column
#: collapses sub-second timestamps to the same string, so we synthesise
#: monotonic millisecond timestamps at 50 Hz to match the model-api default.
SAMPLING_RATE_HZ: int = 50

#: BELT IMU columns we consume (everything else is dropped).
BELT_COLUMNS: tuple[str, ...] = (
    "BELT_ACC_X",
    "BELT_ACC_Y",
    "BELT_ACC_Z",
    "BELT_ANG_X",
    "BELT_ANG_Y",
    "BELT_ANG_Z",
)


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

#: ETL output (committed fixture).
FIXTURE_PATH: Path = Path(__file__).resolve().parent / "fixtures" / "up_fall_windows.jsonl"

#: Default location of the UP-Fall raw CSVs in the cross-repo workspace.
DEFAULT_RAW_ROOT: Path = (
    Path(__file__).resolve().parents[3].parent
    / "Iot_Simulator_clean"
    / "datasets"
    / "05_fall"
    / "UP-Fall"
    / "UP-Fall_Raw"
    / "UP_Fall_Detection_Dataset"
)


# ---------------------------------------------------------------------------
# Data shapes
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class TrialKey:
    """Stable identifier for a (subject, activity, trial) CSV file."""

    subject: str  # e.g. "Subject_01"
    activity: str  # e.g. "A01"
    trial: str  # e.g. "T01"

    @property
    def device_id(self) -> str:
        return f"upfall_{self.subject.lower()}_{self.activity.lower()}_{self.trial.lower()}"

    @property
    def is_fall(self) -> bool:
        return self.activity in FALL_ACTIVITY_CODES


# ---------------------------------------------------------------------------
# CSV parsing
# ---------------------------------------------------------------------------


def parse_belt_rows(csv_path: Path) -> list[tuple[float, float, float, float, float, float]]:
    """Return the ``[ax, ay, az, gx, gy, gz]`` BELT readings from a CSV file.

    Skips rows where any BELT column is malformed (missing / non-numeric).
    Returns an empty list if the header is missing or none of the rows
    parse cleanly.
    """
    rows: list[tuple[float, float, float, float, float, float]] = []
    with csv_path.open("r", newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None or not all(c in reader.fieldnames for c in BELT_COLUMNS):
            return []
        for row in reader:
            try:
                rows.append(
                    (
                        float(row["BELT_ACC_X"]),
                        float(row["BELT_ACC_Y"]),
                        float(row["BELT_ACC_Z"]),
                        float(row["BELT_ANG_X"]),
                        float(row["BELT_ANG_Y"]),
                        float(row["BELT_ANG_Z"]),
                    )
                )
            except (KeyError, ValueError, TypeError):
                continue
    return rows


# ---------------------------------------------------------------------------
# Window extraction
# ---------------------------------------------------------------------------


def find_peak_index(rows: list[tuple[float, ...]]) -> int:
    """Return the index of peak L2 acceleration magnitude.

    Empty input raises :class:`ValueError` — caller must guard.
    """
    if not rows:
        raise ValueError("cannot find peak in empty rows")
    best_idx = 0
    best_mag = -1.0
    for i, r in enumerate(rows):
        ax, ay, az = r[0], r[1], r[2]
        mag = math.sqrt(ax * ax + ay * ay + az * az)
        if mag > best_mag:
            best_mag = mag
            best_idx = i
    return best_idx


#: Min raw samples we accept. Trials shorter than this are skipped because
#: padding ratio gets too high (>20%) and the window stops being
#: representative of real motion.
MIN_RAW_SAMPLES: int = 30


def extract_window(
    rows: list[tuple[float, ...]],
    *,
    window_size: int = WINDOW_SIZE,
) -> list[tuple[float, ...]] | None:
    """Slice a ``window_size`` window centred on peak acceleration.

    Three cases:

    * ``len(rows) >= window_size``: take a peak-centred slice (clamped
      to the trial bounds).
    * ``MIN_RAW_SAMPLES <= len(rows) < window_size``: peak-centre the
      raw samples, then **pre-pad with the first sample value** to
      reach ``window_size``. This simulates the brief pre-event
      stillness a production sliding window catches anyway, and is
      preferable to interpolation (which fabricates dynamics) or
      zero-padding (which the model can learn to recognise as a
      synthetic shape). The padding ratio is reported in the
      summary so callers can spot a degenerate dataset.
    * ``len(rows) < MIN_RAW_SAMPLES``: ``None`` — too short to be
      representative even after padding.
    """
    n = len(rows)
    if n < MIN_RAW_SAMPLES:
        return None
    if n >= window_size:
        peak = find_peak_index(rows)
        half = window_size // 2
        start = max(0, peak - half)
        end = start + window_size
        if end > n:
            end = n
            start = end - window_size
        return rows[start:end]
    # Pre-pad: repeat the first sample so the trial occupies the tail of
    # the window. Centring is irrelevant when the raw trial is shorter
    # than the window — the peak ends up somewhere inside the tail.
    pad_count = window_size - n
    return [rows[0]] * pad_count + list(rows)


# ---------------------------------------------------------------------------
# Mapping to FallPredictionRequest
# ---------------------------------------------------------------------------


def derive_orientation(ax: float, ay: float, az: float) -> tuple[float, float, float]:
    """Approximate ``(pitch, roll, yaw)`` from the gravity-vector projection.

    UP-Fall has no magnetometer so yaw cannot be recovered; we set it to 0
    deliberately rather than guessing. Pitch and roll use the standard
    accelerometer-only formulae and are reasonable for static / slow-moving
    samples; during a fall the values are noisier but still informative.
    """
    pitch = math.atan2(-ax, math.sqrt(ay * ay + az * az))
    roll = math.atan2(ay, az)
    return pitch, roll, 0.0


#: Decimals to round IMU floats to. Fall detection thresholds are in the
#: ~0.1 g (≈0.01 g/s for derivative features) range; 4 decimals preserves
#: ~3 orders of magnitude of headroom while keeping the fixture small.
FLOAT_PRECISION: int = 4


def window_to_request(
    window: list[tuple[float, ...]],
    *,
    device_id: str,
    sampling_rate: int = SAMPLING_RATE_HZ,
) -> dict:
    """Build a ``FallPredictionRequest``-shaped dict from a 50-sample window.

    Output is a plain dict (not the Pydantic model) so the JSONL fixture is
    pure JSON and can be loaded without importing the model-api package.
    Floats are rounded to :data:`FLOAT_PRECISION` decimals to keep the
    checked-in fixture small without affecting fall-detection accuracy.
    """
    interval_ms = round(1000 / sampling_rate)
    samples = []
    p = FLOAT_PRECISION
    for i, row in enumerate(window):
        ax, ay, az, gx, gy, gz = row[:6]
        pitch, roll, yaw = derive_orientation(ax, ay, az)
        samples.append(
            {
                "timestamp": i * interval_ms,
                "accel": {"x": round(ax, p), "y": round(ay, p), "z": round(az, p)},
                "gyro": {"x": round(gx, p), "y": round(gy, p), "z": round(gz, p)},
                "orientation": {
                    "pitch": round(pitch, p),
                    "roll": round(roll, p),
                    "yaw": round(yaw, p),
                },
                "environment": {
                    "floor_vibration": 0.0,
                    "room_occupancy": 0.0,
                    "pressure_mat": 0.0,
                },
            }
        )
    return {
        "device_id": device_id,
        "sampling_rate": sampling_rate,
        "window_size": len(samples),
        "data": samples,
    }


# ---------------------------------------------------------------------------
# Filesystem walk
# ---------------------------------------------------------------------------


def walk_trials(root: Path) -> Iterable[tuple[TrialKey, Path]]:
    """Yield ``(TrialKey, csv_path)`` for every trial CSV under ``root``.

    Sorted by (subject, activity, trial) so the JSONL output is stable
    between runs. Files outside the expected ``Subject_*/A*/S*_A*_T*.csv``
    pattern are silently skipped.
    """
    for subject_dir in sorted(p for p in root.iterdir() if p.is_dir() and p.name.startswith("Subject_")):
        for activity_dir in sorted(p for p in subject_dir.iterdir() if p.is_dir() and p.name.startswith("A")):
            for csv_path in sorted(activity_dir.glob("*.csv")):
                stem = csv_path.stem  # e.g. "S01_A01_T01"
                parts = stem.split("_")
                if len(parts) != 3 or not parts[2].startswith("T"):
                    continue
                yield (
                    TrialKey(subject=subject_dir.name, activity=activity_dir.name, trial=parts[2]),
                    csv_path,
                )


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def generate(
    *,
    raw_root: Path = DEFAULT_RAW_ROOT,
    output: Path = FIXTURE_PATH,
    window_size: int = WINDOW_SIZE,
) -> dict:
    """Walk the raw CSVs and write the labelled JSONL fixture.

    Returns a summary dict with counts so callers (and the unit tests) can
    assert on the output shape without re-parsing the file.
    """
    if not raw_root.exists():
        raise FileNotFoundError(
            f"UP-Fall raw root does not exist: {raw_root}. "
            "Extract Iot_Simulator_clean/datasets/05_fall/UP-Fall/UP-Fall_Dataset.zip first."
        )
    output.parent.mkdir(parents=True, exist_ok=True)

    fall_count = 0
    adl_count = 0
    skipped = 0
    padded_count = 0
    with output.open("w", encoding="utf-8") as out_f:
        for key, csv_path in walk_trials(raw_root):
            if key.activity not in FALL_ACTIVITY_CODES and key.activity not in ADL_ACTIVITY_CODES:
                skipped += 1
                continue
            rows = parse_belt_rows(csv_path)
            raw_len = len(rows)
            window = extract_window(rows, window_size=window_size)
            if window is None:
                skipped += 1
                continue
            request = window_to_request(window, device_id=key.device_id)
            was_padded = raw_len < window_size
            if was_padded:
                padded_count += 1
            line = json.dumps(
                {
                    "label": key.is_fall,
                    "subject": key.subject,
                    "activity": key.activity,
                    "trial": key.trial,
                    "raw_sample_count": raw_len,
                    "padded": was_padded,
                    "request": request,
                },
                separators=(",", ":"),  # compact — keeps the fixture small
            )
            out_f.write(line + "\n")
            if key.is_fall:
                fall_count += 1
            else:
                adl_count += 1

    return {
        "output": str(output),
        "fall_windows": fall_count,
        "adl_windows": adl_count,
        "padded_windows": padded_count,
        "skipped": skipped,
        "total": fall_count + adl_count,
    }


def main() -> None:  # pragma: no cover - CLI entrypoint
    summary = generate()
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":  # pragma: no cover
    main()
