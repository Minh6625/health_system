-- Task 3.18 — Add composite index for cooldown query performance (R10)
-- Used by: calculate_risk() cooldown check (Task 3.12)
-- Pattern: WHERE device_id = ? AND risk_type = ? ORDER BY calculated_at DESC LIMIT 1
--
-- NOTE: Index ix_risk_scores_user_calc on (user_id, calculated_at) NOT created
-- because existing idx_risk_scores_user already covers this pattern.

CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_risk_scores_device_type_calc
    ON risk_scores (device_id, risk_type, calculated_at DESC);
