"""Contract snapshot tests for the mobile-facing risk DTOs.

These tests pin the JSON keys exposed by ``/api/v1/mobile/analysis/*`` and the
nested types (``TopFactorResponse``, ``FactorBreakdownResponse``,
``AiExplanationResponse``, ``SnapshotMetricsResponse``) so that any
field rename / drop is caught at PR time.

When the contract evolves intentionally, update the matching ``EXPECTED_*_KEYS``
sets in :mod:`backend.tests.contract.test_mobile_risk_dto_snapshot` and
bump the contract version in ``backend/docs/risk-contract-baseline.md``.
"""
