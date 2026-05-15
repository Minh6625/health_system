"""Evaluation harness suite for risk-core ML quality gates.

Tests under this package run the full inference pipeline against
labelled benchmark datasets and compute aggregate quality metrics
(sensitivity / specificity / F1 / per-class precision-recall).

Two run modes:

* **Always-on**: ETL helpers + their unit tests. Deterministic, no
  network, fast (< 1 s). Run by ``pytest tests/eval`` like any other
  test module.

* **Gated**: confusion-matrix harness against a live model-api server.
  Skipped unless ``RUN_EVAL=1`` is set in the environment because it
  needs the model-api running on ``settings.model_api_base_url``,
  takes ~1 minute, and writes a dated JSON report to
  ``tests/eval/reports/``.

The Phase 4B-full plan slice 2a calls for these gates **before** any
additional caller is wired into ``POST /api/v1/mobile/telemetry/imu-window``.
"""
