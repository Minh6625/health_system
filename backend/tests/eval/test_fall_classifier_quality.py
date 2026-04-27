"""Gated confusion-matrix harness for the model-api fall classifier.

**Skipped by default.** Run with::

    $env:RUN_EVAL = "1"
    python -m pytest tests/eval/test_fall_classifier_quality.py -v -s

Requires:

* The healthguard-model-api server running on
  ``$env:HEALTHGUARD_MODEL_API_URL`` (defaults to ``http://localhost:8001``)
  with the **fall bundle loaded**.
* The committed fixture at ``tests/eval/fixtures/up_fall_windows.jsonl``.

Pipeline:

1. Read every line of the JSONL fixture (each line = one labelled
   :class:`FallPredictionRequest` body).
2. POST the request body to ``/api/v1/fall/predict`` and parse
   ``results[0].predicted_fall`` as the model's binary classification.
3. Aggregate into a confusion matrix and compute:

   * Sensitivity (TPR) = TP / (TP + FN)
   * Specificity (TNR) = TN / (TN + FP)
   * F1 = 2·precision·recall / (precision + recall)

4. Write a dated JSON report to ``tests/eval/reports/confusion_matrix_*.json``
   so the model owner can inspect every per-window prediction even when
   thresholds pass.
5. Assert against plan §4B.3 thresholds (sensitivity ≥0.90, specificity
   ≥0.85, F1 ≥0.87). Failure raises :class:`AssertionError` with the
   full numbers + the report path so debugging starts with one click.

The same harness can be reused for future fall-model retraining
campaigns — change the fixture, rerun, compare the dated reports.
"""

from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from pathlib import Path

import httpx
import pytest

from tests.eval.etl_up_fall import FIXTURE_PATH

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

#: Plan §4B.3 / §I quality gates.
SENSITIVITY_THRESHOLD: float = 0.90
SPECIFICITY_THRESHOLD: float = 0.85
F1_THRESHOLD: float = 0.87

#: Env var that gates the entire module — opt-in only, never auto-runs in CI.
RUN_EVAL_ENV: str = "RUN_EVAL"

#: Where the model-api lives. Same default as ``ModelApiClient`` so
#: developers have one URL to remember.
DEFAULT_MODEL_API_URL: str = "http://localhost:8001"

#: HTTP timeout for a single POST. Fall predict is fast (<200 ms typical)
#: but allow generous margin for cold-start.
POST_TIMEOUT_SECONDS: float = 30.0

#: Where to write the dated JSON report.
REPORTS_DIR: Path = Path(__file__).resolve().parent / "reports"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _skip_unless_eval_enabled() -> None:
    """Soft-skip the live-harness test unless ``RUN_EVAL=1``.

    Implemented as an explicit call inside the test (not a
    module-level ``pytestmark.skipif``) so the pure-math unit tests
    further down in the same file still run as part of the default
    suite — they don't need the live model-api.
    """
    if os.getenv(RUN_EVAL_ENV, "").strip() != "1":
        pytest.skip(
            f"set {RUN_EVAL_ENV}=1 to run the live-model-api confusion-matrix harness"
        )


def _model_api_url() -> str:
    return os.getenv("HEALTHGUARD_MODEL_API_URL", DEFAULT_MODEL_API_URL).rstrip("/")


def _ensure_model_api_reachable(url: str) -> None:
    """Verify the model-api is up + the fall bundle is loaded.

    Raises :class:`pytest.skip.Exception` (i.e. soft-skips the test) if
    the server is unreachable — this isn't a test failure, just an
    operator setup step.
    """
    try:
        response = httpx.get(f"{url}/api/v1/health", timeout=5.0)
    except httpx.RequestError as exc:
        pytest.skip(f"model-api unreachable at {url}: {exc}")
    if response.status_code != 200:
        pytest.skip(f"model-api health check returned {response.status_code}")
    body = response.json()
    fall_status = body.get("models", {}).get("fall", {}).get("status")
    if fall_status != "loaded":
        pytest.skip(
            f"fall bundle is not loaded on the model-api (status={fall_status!r}). "
            "Place the fall_bundle.joblib in the model-api's models/ directory + restart."
        )


def _post_window(client: httpx.Client, request_body: dict) -> bool:
    """POST one ``FallPredictionRequest`` and return the binary prediction.

    Raises :class:`AssertionError` on any non-200 — we want the harness
    to LOUDLY fail rather than silently mark the row as misclassified
    if the model-api is misbehaving.
    """
    response = client.post("/api/v1/fall/predict", json=request_body)
    assert response.status_code == 200, (
        f"model-api returned {response.status_code} for "
        f"device_id={request_body.get('device_id')!r}: {response.text[:500]}"
    )
    body = response.json()
    results = body.get("results") or []
    assert results, f"empty results from model-api: {body}"
    return bool(results[0]["predicted_fall"])


# ---------------------------------------------------------------------------
# Confusion-matrix maths
# ---------------------------------------------------------------------------


def _confusion_matrix(rows: list[tuple[bool, bool]]) -> dict[str, int]:
    """Tally ``(actual_label, predicted_label)`` pairs into TP/TN/FP/FN."""
    tp = sum(1 for actual, pred in rows if actual and pred)
    tn = sum(1 for actual, pred in rows if not actual and not pred)
    fp = sum(1 for actual, pred in rows if not actual and pred)
    fn = sum(1 for actual, pred in rows if actual and not pred)
    return {"tp": tp, "tn": tn, "fp": fp, "fn": fn}


def _metrics(cm: dict[str, int]) -> dict[str, float]:
    tp, tn, fp, fn = cm["tp"], cm["tn"], cm["fp"], cm["fn"]
    sensitivity = tp / (tp + fn) if (tp + fn) else 0.0
    specificity = tn / (tn + fp) if (tn + fp) else 0.0
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    f1 = (2 * precision * sensitivity / (precision + sensitivity)) if (precision + sensitivity) else 0.0
    accuracy = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) else 0.0
    return {
        "sensitivity": round(sensitivity, 4),
        "specificity": round(specificity, 4),
        "precision": round(precision, 4),
        "f1": round(f1, 4),
        "accuracy": round(accuracy, 4),
    }


# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------


def test_fall_classifier_meets_quality_thresholds() -> None:
    """Run the full UP-Fall fixture against the model-api and gate on
    sensitivity / specificity / F1.

    On failure the assertion message includes the confusion matrix + the
    path to the JSON report so debugging starts with one click.
    """
    _skip_unless_eval_enabled()
    assert FIXTURE_PATH.exists(), (
        f"Fixture not found at {FIXTURE_PATH}. Run "
        "`python -m tests.eval.etl_up_fall` to regenerate."
    )
    base_url = _model_api_url()
    _ensure_model_api_reachable(base_url)

    rows: list[tuple[bool, bool]] = []
    per_window: list[dict] = []
    with FIXTURE_PATH.open("r", encoding="utf-8") as f, httpx.Client(
        base_url=base_url, timeout=POST_TIMEOUT_SECONDS,
    ) as client:
        for line_no, line in enumerate(f, start=1):
            entry = json.loads(line)
            actual = bool(entry["label"])
            predicted = _post_window(client, entry["request"])
            rows.append((actual, predicted))
            per_window.append(
                {
                    "subject": entry["subject"],
                    "activity": entry["activity"],
                    "trial": entry["trial"],
                    "padded": entry["padded"],
                    "actual": actual,
                    "predicted": predicted,
                    "correct": actual == predicted,
                }
            )
            if line_no % 25 == 0:
                print(f"  ... {line_no} windows processed")

    cm = _confusion_matrix(rows)
    metrics = _metrics(cm)

    # Persist a dated report unconditionally — operators want it on
    # success too (for trend analysis).
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    report_path = REPORTS_DIR / f"confusion_matrix_{timestamp}.json"
    report_path.write_text(
        json.dumps(
            {
                "ran_at_utc": datetime.now(UTC).isoformat(),
                "model_api_url": base_url,
                "fixture": str(FIXTURE_PATH),
                "thresholds": {
                    "sensitivity": SENSITIVITY_THRESHOLD,
                    "specificity": SPECIFICITY_THRESHOLD,
                    "f1": F1_THRESHOLD,
                },
                "confusion_matrix": cm,
                "metrics": metrics,
                "per_window": per_window,
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    # Surface the report path in the test output so a passing run still
    # tells the operator where to find the raw numbers.
    print()
    print(f"Report: {report_path}")
    print(f"Confusion matrix: {cm}")
    print(f"Metrics: {metrics}")

    # Gate. All three thresholds must pass — assert in one block so a
    # single failure shows ALL the numbers, not just the first miss.
    failures: list[str] = []
    if metrics["sensitivity"] < SENSITIVITY_THRESHOLD:
        failures.append(
            f"sensitivity={metrics['sensitivity']} < {SENSITIVITY_THRESHOLD} "
            f"(missed {cm['fn']}/{cm['tp'] + cm['fn']} real falls)"
        )
    if metrics["specificity"] < SPECIFICITY_THRESHOLD:
        failures.append(
            f"specificity={metrics['specificity']} < {SPECIFICITY_THRESHOLD} "
            f"(false-positive on {cm['fp']}/{cm['tn'] + cm['fp']} ADLs)"
        )
    if metrics["f1"] < F1_THRESHOLD:
        failures.append(f"f1={metrics['f1']} < {F1_THRESHOLD}")
    assert not failures, (
        "Fall classifier quality gates failed:\n  - "
        + "\n  - ".join(failures)
        + f"\nReport: {report_path}"
    )


# ---------------------------------------------------------------------------
# Pure-math unit tests for the helpers above — always-on, no live model-api.
# ---------------------------------------------------------------------------


class TestConfusionMatrixMaths:
    def test_perfect_classifier(self) -> None:
        rows = [(True, True), (False, False), (True, True), (False, False)]
        cm = _confusion_matrix(rows)
        m = _metrics(cm)
        assert cm == {"tp": 2, "tn": 2, "fp": 0, "fn": 0}
        assert m["sensitivity"] == 1.0
        assert m["specificity"] == 1.0
        assert m["f1"] == 1.0

    def test_all_false_positives(self) -> None:
        rows = [(False, True), (False, True)]
        cm = _confusion_matrix(rows)
        m = _metrics(cm)
        assert cm == {"tp": 0, "tn": 0, "fp": 2, "fn": 0}
        assert m["specificity"] == 0.0
        # No positives at all -> sensitivity = 0 (no FN, no TP).
        assert m["sensitivity"] == 0.0
        # Precision = 0 -> F1 = 0.
        assert m["f1"] == 0.0

    def test_metrics_roundtrip(self) -> None:
        # 8 actual falls, 6 detected -> sensitivity = 6/8 = 0.75
        # 12 ADLs, 11 correctly identified -> specificity = 11/12 ≈ 0.9167
        rows = (
            [(True, True)] * 6
            + [(True, False)] * 2
            + [(False, False)] * 11
            + [(False, True)] * 1
        )
        cm = _confusion_matrix(rows)
        m = _metrics(cm)
        assert cm == {"tp": 6, "tn": 11, "fp": 1, "fn": 2}
        assert m["sensitivity"] == 0.75
        assert m["specificity"] == 0.9167
