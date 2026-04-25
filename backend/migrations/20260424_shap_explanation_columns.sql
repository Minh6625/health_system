-- ============================================================================
-- Migration: Add SHAP + structured explanation columns to risk_explanations
-- Date: 2026-04-24
-- Purpose: Support rich SHAP top_features and AI explanation payloads from
--          healthguard-model-api (Flutter UI SHAP refactor — Phase A).
-- ============================================================================

-- top_features: JSONB list of {feature, feature_value, impact, direction, reason}
ALTER TABLE risk_explanations
    ADD COLUMN IF NOT EXISTS top_features_json JSONB;

-- ai_explanation: JSONB object {short_text, clinical_note, recommended_actions}
ALTER TABLE risk_explanations
    ADD COLUMN IF NOT EXISTS ai_explanation_json JSONB;

-- shap_details: optional SHAP waterfall payload {base_value, prediction_value, values[]}
ALTER TABLE risk_explanations
    ADD COLUMN IF NOT EXISTS shap_details_json JSONB;

COMMENT ON COLUMN risk_explanations.top_features_json IS
    'Structured SHAP top_features from model-api (impact, direction, reason per feature).';
COMMENT ON COLUMN risk_explanations.ai_explanation_json IS
    'Structured PredictionExplanation from model-api (short_text, clinical_note, recommended_actions).';
COMMENT ON COLUMN risk_explanations.shap_details_json IS
    'Optional SHAP waterfall payload for advanced visualization.';
