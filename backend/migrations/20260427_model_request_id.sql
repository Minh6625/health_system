-- ============================================================================
-- Migration: Add model_request_id traceability column to risk_explanations
-- Date: 2026-04-27
-- Phase: 2 (focused subset — see backend/docs/risk-contract-baseline.md §7d)
-- Purpose: Persist the upstream healthguard-model-api ``meta.request_id`` so
--          backend logs (``risk_alert_service``, ``model_api_client``) can be
--          correlated end-to-end with model-api server-side logs by
--          request_id when investigating production incidents.
--
-- Rollout notes:
--   * Column is nullable so the migration is forward-compatible: existing
--     rows keep ``NULL``, the rule_based / ONNX fallback paths also write
--     ``NULL`` (they have no upstream request to correlate with). Only rows
--     produced via the model-api path will populate this column.
--   * The accompanying ORM change (``app/models/risk_explanation_model.py``)
--     and persistence adapter change (``app/adapters/risk_persistence_adapter.py``)
--     start writing the column on the next deploy. There is no backfill
--     for historical rows because the upstream request_id is not retained
--     anywhere they could be reconstructed from.
--   * Index is partial (only NOT NULL rows) so it stays small even with
--     years of historical rule_based rows that all carry NULL.
-- ============================================================================

ALTER TABLE risk_explanations
    ADD COLUMN IF NOT EXISTS model_request_id VARCHAR(36);

-- Partial index because the rule_based / fallback paths intentionally write
-- NULL; we only ever query on this column when chasing a model-api log line,
-- so indexing the NULL rows wastes space.
CREATE INDEX IF NOT EXISTS idx_risk_explanations_model_request_id
    ON risk_explanations (model_request_id)
    WHERE model_request_id IS NOT NULL;

COMMENT ON COLUMN risk_explanations.model_request_id IS
    'healthguard-model-api meta.request_id for end-to-end log correlation; '
    'NULL on rows produced by the local rule_based / ONNX / LightGBM fallback paths.';
