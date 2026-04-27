-- ============================================================================
-- Migration: Relax risk_scores.risk_type CHECK to include 'sleep'
-- Date: 2026-04-27
-- Phase: 4A (focused subset — see backend/docs/risk-contract-baseline.md §7f)
-- Purpose: Allow ``risk_scores`` rows to carry ``risk_type='sleep'`` so the
--          new POST /mobile/telemetry/sleep-risk route can persist sleep
--          risk inferences alongside existing ``general`` (vitals) rows.
--
-- Rollout notes:
--   * Forward-compatible — relaxing a CHECK can only succeed; existing
--     rows already match the relaxed predicate (their ``risk_type`` value
--     is in the prior allowed set, which is a strict subset of the new
--     allowed set).
--   * The constraint is named ``check_risk_type`` (matches the ORM
--     declaration in ``app/models/risk_score_model.py``); we drop and
--     re-add by the same name so the SQLAlchemy metadata stays in sync.
--   * Plan section 4A flags that ``risk_type='fall'`` is NOT added here;
--     fall events live in their own ``fall_events`` table per Phase 4B
--     (different lifecycle: alert-state vs continuous trend).
-- ============================================================================

ALTER TABLE risk_scores
    DROP CONSTRAINT IF EXISTS check_risk_type;

ALTER TABLE risk_scores
    ADD CONSTRAINT check_risk_type
    CHECK (risk_type IN ('stroke', 'heartattack', 'afib', 'general', 'sleep'));

COMMENT ON COLUMN risk_scores.risk_type IS
    'Risk domain: ``general`` (vitals), ``stroke`` / ``heartattack`` / ``afib`` '
    '(legacy vital-derived flags), or ``sleep`` (sleep score risk inversion). '
    'Fall events live in the separate ``fall_events`` table.';
