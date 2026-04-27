-- ============================================================================
-- Migration: Add audience_payload_json cache column to risk_explanations
-- Date: 2026-04-27
-- Phase: 7 (audience-payload cache — see backend/docs/risk-contract-baseline.md §7h)
-- Purpose: Cache the assembled mobile DTOs (one payload per audience profile)
--          on the same row that produced them so the read path can serve
--          repeat detail requests without re-running the SHAP / breakdown /
--          DTO assembly pipeline.
--
-- Cache shape: ``{"<audience>": {"contract_version": "<x.y.z>", "payload": {...}}}``
--              keyed by audience profile (``patient`` / ``clinician``). The
--              contract version is embedded so a Phase-bump auto-invalidates
--              every cached row without a manual flush job.
--
-- Rollout notes:
--   * Forward-compatible — column is nullable so pre-Phase-7 rows return
--     ``NULL`` and the read path falls back to the existing assembly flow.
--   * Partial index on ``IS NOT NULL`` so the index stays small even with
--     years of legacy NULL rows.
--   * Disk usage estimate: one detail payload ≈ 4-8 KB; with 100k users ×
--     10 reports ≈ 6 GB. Acceptable for now; future TTL cleanup is a
--     separate workstream.
-- ============================================================================

ALTER TABLE risk_explanations
    ADD COLUMN IF NOT EXISTS audience_payload_json JSONB;

CREATE INDEX IF NOT EXISTS idx_risk_explanations_audience_payload_present
    ON risk_explanations ((audience_payload_json IS NOT NULL))
    WHERE audience_payload_json IS NOT NULL;

COMMENT ON COLUMN risk_explanations.audience_payload_json IS
    'Phase 7 cache: pre-assembled mobile DTOs keyed by audience profile. '
    'Shape: {"<audience>": {"contract_version": "x.y.z", "payload": {...}}}. '
    'Cache miss = NULL or contract version drift; either case rebuilds via '
    'MonitoringService and overwrites this column.';
