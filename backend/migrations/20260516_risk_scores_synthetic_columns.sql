-- ============================================================================
-- Migration: Promote ADR-018 data-quality contract from features JSONB to
--            first-class columns on risk_scores
-- Date: 2026-05-16
-- Phase: 7 (Redesign IoT Sim 2026 — Slice S4)
-- ADR: ADR-018 — Health Input Validation Contract (Fail-Closed + Synthetic Flag)
-- Refs: PM_REVIEW/REDESIGN_IOT_SIM_2026/04_adr_proposals/ADR-018-health-input-validation-contract.md
--       PM_REVIEW/BUGS/HS-024-risk-inference-silent-default-fill.md
--       PM_REVIEW/BUGS/XR-003-model-api-input-validation-contract.md
--
-- Purpose:
--   The data-quality contract defined by ADR-018 was previously persisted
--   only inside the ``risk_scores.features`` JSONB blob. That works for the
--   mobile read path (MonitoringService projects the blob into the DTO),
--   but blocks two downstream consumers that need queryable columns:
--     * Admin dashboard analytics ("how many records had defaulted vitals
--       last week?")
--     * Retraining pipeline gating ("exclude synthetic-default rows from
--       the training corpus")
--     * Audit / compliance reports (proof of fail-closed behaviour over
--       time)
--
--   Slice S4 promotes four contract fields to real columns:
--     * is_synthetic_default BOOLEAN — true if any soft field was defaulted
--     * defaults_applied      JSONB — list of soft field names that were
--                                     defaulted (NULL when none)
--     * effective_confidence  DECIMAL(5,4) — degraded confidence (= raw
--                                     confidence × 0.5 when synthetic, else
--                                     raw confidence). NULL on rule-based
--                                     fallback path which has no quality
--                                     contract.
--     * data_quality_warning  TEXT — human-readable warning produced by
--                                     model-api when soft defaults applied.
--                                     NULL on clean records.
--
-- Rollout notes:
--   * Forward-compatible, additive only — every column is nullable except
--     is_synthetic_default which has a server-side default of FALSE so old
--     rows get a safe value without rewriting the row.
--   * features JSONB blob STILL carries the same defaults_applied list so
--     the existing read path (MonitoringService._normalize_risk_row) keeps
--     working unchanged. The column is a duplicate optimised for query —
--     not a replacement.
--   * Partial index on is_synthetic_default = true so analytics queries
--     ("WHERE is_synthetic_default") stay fast as the table grows.
--   * No data backfill needed — historical rows default to FALSE / NULL
--     which matches their pre-S4 semantics ("we did not track this back
--     then so treat as unknown / clean").
-- ============================================================================

ALTER TABLE risk_scores
    ADD COLUMN IF NOT EXISTS is_synthetic_default BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS defaults_applied JSONB,
    ADD COLUMN IF NOT EXISTS effective_confidence DECIMAL(5,4),
    ADD COLUMN IF NOT EXISTS data_quality_warning TEXT;

CREATE INDEX IF NOT EXISTS idx_risk_scores_is_synthetic_default
    ON risk_scores (is_synthetic_default, calculated_at DESC)
    WHERE is_synthetic_default = TRUE;

COMMENT ON COLUMN risk_scores.is_synthetic_default IS
    'ADR-018 / Phase 7 S4: TRUE when at least one soft field (BP, HRV, weight, '
    'height) was defaulted during inference. FALSE on fully-real-vitals records '
    'and on the local rule-based fallback path that did not default anything.';

COMMENT ON COLUMN risk_scores.defaults_applied IS
    'ADR-018 / Phase 7 S4: ordered list of soft field names that were defaulted '
    'for this inference (e.g. ["hrv","weight_kg"]). NULL on clean records to '
    'enable "WHERE defaults_applied IS NOT NULL" scans for synthetic-only '
    'analytics. Mirror of the same key inside the features JSONB blob.';

COMMENT ON COLUMN risk_scores.effective_confidence IS
    'ADR-018 / Phase 7 S4: confidence the consumer should display. Equals raw '
    'confidence × 0.5 when is_synthetic_default = TRUE, equals raw confidence '
    'otherwise. NULL on the local rule-based fallback path which does not '
    'produce the quality contract. Range 0.0000-1.0000.';

COMMENT ON COLUMN risk_scores.data_quality_warning IS
    'ADR-018 / Phase 7 S4: human-readable warning emitted by the model-api '
    'when soft defaults were applied (e.g. "Một số chỉ số (hrv) được ước tính"). '
    'NULL on clean records and on the local fallback path.';
