"""Mobile risk contract version + helpers.

Phase 6 (see ``backend/docs/risk-contract-baseline.md``) introduces a
single source of truth for the version of the **mobile-facing risk DTO
contract** so older Flutter binaries can detect that they are talking to
an incompatible backend instead of silently mis-parsing the response.

The version is sent on every response from the mobile risk routes via
the ``X-Risk-Contract-Version`` header. The mobile ``ApiClient``
(``lib/core/network/api_client.dart``) reads it back, stores the latest
seen value, and emits a debug warning when it does not match the
expected value.

The version intentionally mirrors the **Baseline version** from the
contract baseline doc rather than the FastAPI ``app.version`` (which
tracks the backend deploy as a whole). They are decoupled: a backend
re-deploy that does not touch the mobile risk surface should NOT bump
the contract version.

Bumping rules:

- ``patch`` bump (``0.4.0 -> 0.4.1``) — internal refactor, no observable
  change to the mobile JSON shape (e.g. Phase 3a typed-row refactor).
- ``minor`` bump (``0.4.x -> 0.5.0``) — additive change: new fields, new
  query params, new optional headers. Older clients keep working because
  every new field is optional.
- ``major`` bump (``0.x.y -> 1.0.0``) — breaking change: a deprecated
  field is removed, a key is renamed, a type changes.

When you bump the version here, also update:

1. ``backend/docs/risk-contract-baseline.md`` (top header + version
   history table).
2. The ``EXPECTED_*_KEYS`` snapshot tests if the wire shape changed.
3. The mobile ``RiskAnalysisRepository.expectedContractVersion``
   constant so the warning fires on the binaries that were built against
   the previous version.
"""

from __future__ import annotations

from typing import Final

#: Header name used on every mobile risk route response.
RISK_CONTRACT_VERSION_HEADER: Final[str] = "X-Risk-Contract-Version"

#: Current mobile risk contract version.
#:
#: Sync with the **Baseline version** in
#: ``backend/docs/risk-contract-baseline.md`` and with the matching
#: ``RiskAnalysisRepository.expectedContractVersion`` constant on the
#: Flutter side.
#:
#: Phase 5 minor bump (``0.4.0 -> 0.5.0``): the detail route now emits
#: a Union response type — patient (unchanged) or clinician (additive
#: ``shap_details`` + ``model_request_id``). Older clients that always
#: get patient see no shape change; clients that ask for clinician opt
#: in to the new fields.
RISK_CONTRACT_VERSION: Final[str] = "0.5.0"

#: URL prefixes whose responses should carry the contract version header.
#:
#: Kept narrow on purpose: the version describes the **risk DTO contract**
#: only; auth, vitals ingestion and notification routes are not part of
#: it and bumping them would be a category error.
#:
#: Note that ``/health-report`` is mounted under ``/api/v1/mobile/metrics/``
#: (it is a snapshot of the latest vitals + the latest risk score),
#: while ``/risk-reports``, ``/risk-reports/{id}`` and ``/risk-history``
#: live under ``/api/v1/mobile/analysis/``.
#:
#: ADR-021 post-execution: only the canonical ``/api/v1/mobile/...`` prefix
#: is served (the FastAPI ``root_path`` magic has been removed so both
#: production and TestClient see the same path).
RISK_CONTRACT_ROUTE_PREFIXES: Final[tuple[str, ...]] = (
    "/api/v1/mobile/analysis/risk-reports",
    "/api/v1/mobile/analysis/risk-history",
    "/api/v1/mobile/metrics/health-report",
)


def applies_to_path(path: str) -> bool:
    """Return ``True`` if ``path`` is in the risk contract surface.

    Used by the response middleware to decide whether to inject the
    ``X-Risk-Contract-Version`` header.
    """
    return path.startswith(RISK_CONTRACT_ROUTE_PREFIXES)
