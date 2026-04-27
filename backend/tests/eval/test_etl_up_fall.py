"""Always-on unit tests for the UP-Fall ETL helpers.

Pins the deterministic ETL behaviour (peak detection, window extraction,
label mapping, request shape) so a future contributor can refactor the
ETL with confidence. Does NOT exercise the live model-api or load the
1.5 MB committed fixture — those are the gated harness's job.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.eval.etl_up_fall import (
    ADL_ACTIVITY_CODES,
    FALL_ACTIVITY_CODES,
    FIXTURE_PATH,
    MIN_RAW_SAMPLES,
    WINDOW_SIZE,
    TrialKey,
    derive_orientation,
    extract_window,
    find_peak_index,
    parse_belt_rows,
    walk_trials,
    window_to_request,
)


# ---------------------------------------------------------------------------
# Activity taxonomy
# ---------------------------------------------------------------------------


class TestActivityTaxonomy:
    def test_fall_and_adl_codes_are_disjoint(self) -> None:
        # The harness's confusion matrix maps activities to a single
        # binary class — overlap would produce ambiguous labels.
        assert FALL_ACTIVITY_CODES.isdisjoint(ADL_ACTIVITY_CODES)

    def test_trial_key_is_fall_for_fall_codes(self) -> None:
        for code in FALL_ACTIVITY_CODES:
            key = TrialKey(subject="Subject_01", activity=code, trial="T01")
            assert key.is_fall is True, code

    def test_trial_key_is_adl_for_adl_codes(self) -> None:
        for code in ADL_ACTIVITY_CODES:
            key = TrialKey(subject="Subject_01", activity=code, trial="T01")
            assert key.is_fall is False, code

    def test_device_id_is_lowercased_and_namespaced(self) -> None:
        key = TrialKey(subject="Subject_03", activity="A02", trial="T01")
        assert key.device_id == "upfall_subject_03_a02_t01"


# ---------------------------------------------------------------------------
# Peak detection
# ---------------------------------------------------------------------------


class TestPeakDetection:
    def test_returns_index_of_max_l2_magnitude(self) -> None:
        rows = [
            (0.1, 0.0, 0.0, 0.0, 0.0, 0.0),
            (0.2, 0.2, 0.2, 0.0, 0.0, 0.0),  # mag ≈ 0.346
            (3.0, 4.0, 0.0, 0.0, 0.0, 0.0),  # mag = 5.0 (peak)
            (1.0, 1.0, 1.0, 0.0, 0.0, 0.0),  # mag ≈ 1.732
        ]
        assert find_peak_index(rows) == 2

    def test_empty_rows_raise(self) -> None:
        with pytest.raises(ValueError):
            find_peak_index([])

    def test_picks_first_when_tied(self) -> None:
        # Two peaks at the same magnitude — argmax returns the first.
        rows = [
            (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
            (3.0, 4.0, 0.0, 0.0, 0.0, 0.0),
            (4.0, 3.0, 0.0, 0.0, 0.0, 0.0),
        ]
        assert find_peak_index(rows) == 1


# ---------------------------------------------------------------------------
# Window extraction
# ---------------------------------------------------------------------------


class TestWindowExtraction:
    def test_long_trial_returns_peak_centred_window(self) -> None:
        # 200 samples; peak at index 100; window_size=50 -> window [75:125].
        rows: list[tuple[float, ...]] = [
            (0.1, 0.0, 0.0, 0.0, 0.0, 0.0)
        ] * 100 + [(5.0, 0.0, 0.0, 0.0, 0.0, 0.0)] + [
            (0.1, 0.0, 0.0, 0.0, 0.0, 0.0)
        ] * 99
        window = extract_window(rows, window_size=50)
        assert window is not None
        assert len(window) == 50
        # Peak (the (5.0, ...) sample) must land inside the window.
        assert any(r[0] == 5.0 for r in window)

    def test_short_trial_below_min_returns_none(self) -> None:
        rows = [(0.1, 0.0, 0.0, 0.0, 0.0, 0.0)] * (MIN_RAW_SAMPLES - 1)
        assert extract_window(rows) is None

    def test_short_trial_above_min_pre_pads_with_first_sample(self) -> None:
        # 40-sample trial — exactly the case the UP-Fall fall trials hit.
        first = (1.0, 2.0, 3.0, 0.0, 0.0, 0.0)
        rows: list[tuple[float, ...]] = [first] + [
            (0.1 * i, 0.0, 9.81, 0.05, 0.05, 0.05) for i in range(1, 40)
        ]
        window = extract_window(rows, window_size=50)
        assert window is not None
        assert len(window) == 50
        # First 10 entries should be the pre-pad (all equal to ``first``).
        assert window[:10] == [first] * 10
        # Tail 40 entries are the original trial verbatim.
        assert window[10:] == rows

    def test_exact_window_size_passes_through_centred(self) -> None:
        rows = [(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)] * 25 + [
            (5.0, 0.0, 0.0, 0.0, 0.0, 0.0)
        ] + [(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)] * 24
        window = extract_window(rows, window_size=50)
        assert window is not None
        assert len(window) == 50
        # Peak still in the slice.
        assert any(r[0] == 5.0 for r in window)


# ---------------------------------------------------------------------------
# Orientation derivation
# ---------------------------------------------------------------------------


class TestOrientationDerivation:
    def test_yaw_is_always_zero(self) -> None:
        # UP-Fall has no magnetometer; deriving yaw would be guessing.
        for accel in [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), (0.5, 0.5, 0.5)]:
            _, _, yaw = derive_orientation(*accel)
            assert yaw == 0.0

    def test_flat_z_axis_gives_near_zero_pitch_and_roll(self) -> None:
        # Sensor laying flat on a surface, pure gravity on +Z.
        pitch, roll, _ = derive_orientation(0.0, 0.0, 1.0)
        assert abs(pitch) < 1e-9
        assert abs(roll) < 1e-9


# ---------------------------------------------------------------------------
# Request mapping
# ---------------------------------------------------------------------------


class TestWindowToRequest:
    def test_request_matches_fall_prediction_shape(self) -> None:
        window = [(0.1, 0.0, 0.0, 0.0, 0.0, 0.0)] * 50
        request = window_to_request(window, device_id="dev_01")
        # Top-level fields per FallPredictionRequest.
        assert request["device_id"] == "dev_01"
        assert request["sampling_rate"] == 50
        assert request["window_size"] == 50
        assert len(request["data"]) == 50
        sample = request["data"][0]
        # SensorSample fields.
        assert set(sample.keys()) == {
            "timestamp", "accel", "gyro", "orientation", "environment",
        }
        assert set(sample["accel"].keys()) == {"x", "y", "z"}
        assert set(sample["gyro"].keys()) == {"x", "y", "z"}
        assert set(sample["orientation"].keys()) == {"pitch", "roll", "yaw"}
        assert set(sample["environment"].keys()) == {
            "floor_vibration", "room_occupancy", "pressure_mat",
        }

    def test_timestamps_increase_at_sampling_interval(self) -> None:
        window = [(0.1, 0.0, 0.0, 0.0, 0.0, 0.0)] * 50
        request = window_to_request(window, device_id="dev_01", sampling_rate=50)
        ts = [s["timestamp"] for s in request["data"]]
        # 50 Hz -> 20 ms between consecutive samples.
        assert ts == [i * 20 for i in range(50)]

    def test_floats_rounded_to_four_decimals(self) -> None:
        # 0.123456789 -> 0.1235 after round(p=4).
        window = [(0.123456789, 0.0, 0.0, 0.0, 0.0, 0.0)] * 50
        request = window_to_request(window, device_id="dev")
        assert request["data"][0]["accel"]["x"] == 0.1235


# ---------------------------------------------------------------------------
# Filesystem walk + dataset existence
# ---------------------------------------------------------------------------


class TestDatasetWalk:
    def test_walks_subject_activity_trial_in_sorted_order(self, tmp_path: Path) -> None:
        # Build a minimal fake dataset on disk.
        subj = tmp_path / "Subject_02"
        (subj / "A03").mkdir(parents=True)
        (subj / "A01").mkdir(parents=True)
        (subj / "A03" / "S02_A03_T02.csv").write_text("TIME\n")
        (subj / "A03" / "S02_A03_T01.csv").write_text("TIME\n")
        (subj / "A01" / "S02_A01_T01.csv").write_text("TIME\n")
        # One non-pattern file that should be skipped.
        (subj / "A01" / "junk.csv").write_text("")

        keys = [k for k, _ in walk_trials(tmp_path)]
        # Sorted by activity ascending, trial ascending; junk skipped.
        assert keys == [
            TrialKey(subject="Subject_02", activity="A01", trial="T01"),
            TrialKey(subject="Subject_02", activity="A03", trial="T01"),
            TrialKey(subject="Subject_02", activity="A03", trial="T02"),
        ]


# ---------------------------------------------------------------------------
# CSV parsing tolerance
# ---------------------------------------------------------------------------


class TestParseBeltRows:
    def test_missing_header_returns_empty(self, tmp_path: Path) -> None:
        f = tmp_path / "no_header.csv"
        f.write_text("not,really,a,csv\n1,2,3,4\n")
        assert parse_belt_rows(f) == []

    def test_skips_rows_with_non_numeric_values(self, tmp_path: Path) -> None:
        header = ",".join([
            "TIME", "BELT_ACC_X", "BELT_ACC_Y", "BELT_ACC_Z",
            "BELT_ANG_X", "BELT_ANG_Y", "BELT_ANG_Z",
        ])
        good = "2026,1.0,2.0,3.0,0.1,0.2,0.3"
        bad = "2026,oops,2.0,3.0,0.1,0.2,0.3"
        f = tmp_path / "mixed.csv"
        f.write_text(f"{header}\n{good}\n{bad}\n{good}\n")
        rows = parse_belt_rows(f)
        assert rows == [(1.0, 2.0, 3.0, 0.1, 0.2, 0.3), (1.0, 2.0, 3.0, 0.1, 0.2, 0.3)]


# ---------------------------------------------------------------------------
# Committed fixture sanity
# ---------------------------------------------------------------------------


class TestCommittedFixture:
    """Light-touch sanity checks on the checked-in JSONL output.

    These tests don't load every line; they just verify the file exists
    in the expected location, parses as valid JSON line-by-line, and has
    the expected per-line shape. Heavy aggregate checks live in the
    gated harness (which reads every line anyway).
    """

    def test_fixture_file_exists_and_is_jsonl(self) -> None:
        if not FIXTURE_PATH.exists():
            pytest.skip(
                f"Fixture {FIXTURE_PATH} is missing — run "
                "`python -m tests.eval.etl_up_fall` to regenerate."
            )
        with FIXTURE_PATH.open("r", encoding="utf-8") as f:
            first = json.loads(f.readline())
        # Required top-level keys.
        for key in ("label", "subject", "activity", "trial", "raw_sample_count", "padded", "request"):
            assert key in first, f"Fixture row missing key: {key}"
        # Window must always be exactly WINDOW_SIZE samples regardless of
        # whether padding was applied — the model-api requires it.
        assert len(first["request"]["data"]) == WINDOW_SIZE

    def test_fixture_balances_falls_and_adls(self) -> None:
        if not FIXTURE_PATH.exists():
            pytest.skip("Fixture missing")
        labels = []
        with FIXTURE_PATH.open("r", encoding="utf-8") as f:
            for line in f:
                labels.append(json.loads(line)["label"])
        falls = sum(labels)
        adls = len(labels) - falls
        # Loose lower bounds — defending against a future ETL bug that
        # silently drops one class. The exact 57/69 numbers are
        # dataset-specific and would over-pin the test.
        assert falls >= 30, f"Suspiciously few fall windows: {falls}"
        assert adls >= 30, f"Suspiciously few ADL windows: {adls}"
