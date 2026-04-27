# `tests/eval/` — ML quality harness

Phase 4B-full slice 2a (see plan
[`risk-core-final-completion-9ea607.md`](../../../../../../C:\Users\MrThien\.windsurf\plans\risk-core-final-completion-9ea607.md)).
Defends the v0.8 backend fall route's accuracy with a confusion-matrix
gate **before** the rest of Phase 4B (simulator dispatch, mobile UI,
push channel) is wired in.

## Layout

```
backend/tests/eval/
├── etl_up_fall.py              # ETL: UP-Fall raw CSVs -> labelled JSONL
├── fixtures/up_fall_windows.jsonl   # checked-in deterministic ETL output
├── test_etl_up_fall.py         # always-on unit tests (peak detection, window extraction, label mapping)
├── test_fall_classifier_quality.py  # GATED harness — RUN_EVAL=1
└── reports/                    # dated JSON report output dir
```

## Always-on tests

Run with the rest of the suite:

```bash
cd backend
python -m pytest tests/eval/test_etl_up_fall.py
```

Three deterministic tests covering the ETL helpers — no network, no
model-api, no large fixture loads. Fast.

## Gated confusion-matrix harness

Needs the model-api server running on
``settings.model_api_base_url`` (defaults to ``http://localhost:8090``)
with the **fall bundle loaded**:

```bash
# Terminal 1 — start model-api
cd healthguard-model-api
python -m uvicorn app.main:app --host 0.0.0.0 --port 8090

# Terminal 2 — run the gated test
cd health_system/backend
$env:RUN_EVAL = "1"
python -m pytest tests/eval/test_fall_classifier_quality.py -v -s
```

The harness POSTs each labelled window to ``/api/v1/fall/predict``,
collects the model's binary classification, and computes the
confusion matrix + sensitivity / specificity / F1.

### Acceptance thresholds

From plan §I and §4B.3:

| Metric | Threshold | Why |
|---|---|---|
| Sensitivity (TP / (TP + FN)) | ≥ **0.90** | False negatives on real falls are dangerous — a missed alert can mean an untreated injury for an elderly user. |
| Specificity (TN / (TN + FP)) | ≥ **0.85** | Excessive false alarms erode user trust + cause alarm fatigue. |
| F1 | ≥ **0.87** | Combined balance check. |

If any threshold fails, the harness raises ``AssertionError`` with the
full confusion matrix + per-window breakdown so the model owner can
debug. The fall route ships behind a feature flag in production until
all three thresholds clear.

## Why UP-Fall, not PAMAP2

The original plan listed both UP-Fall (falls) and PAMAP2 (non-fall
ADLs) as inputs. **Audit found PAMAP2 is not present in the simulator
repo** (only an empty `PAMAP2_Raw/` directory). UP-Fall already ships
with both classes — A01–A05 are falls, A06–A11 are ADLs (walking,
standing, sitting, picking up, jumping, laying) — so the harness has
positive + negative samples without needing a second dataset.

If PAMAP2 data is added later, drop a parallel ``etl_pamap2.py`` +
fixture under this directory and extend the harness's input loader to
combine both. The threshold gate logic stays identical.
