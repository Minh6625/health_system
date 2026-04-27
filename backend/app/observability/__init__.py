"""Observability primitives for the risk pipeline (Phase 7).

Currently exposes a single helper, :func:`record_timing`, used to time
the four orchestration stages the plan calls out:

* ``build_record`` — adapter ``ModelApiHealthAdapter.to_record``
* ``model_api_call`` — outbound HTTP to healthguard-model-api
* ``persist`` — DB writes through ``RiskPersistenceAdapter.persist``
* ``build_dto`` — mobile DTO assembly via ``risk_report_builder``

The helper writes a single structured log line per timing event so a
log aggregator (cloud logging, ELK, Loki, ...) can build histograms
without the backend carrying a metrics dependency at runtime.
"""

from app.observability.timing import StageTimer, record_timing

__all__ = ["StageTimer", "record_timing"]
