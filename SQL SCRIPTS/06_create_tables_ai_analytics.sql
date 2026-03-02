-- ============================================================================
-- File: 06_create_tables_ai_analytics.sql
-- Description: Tạo bảng cho AI/ML (risk scores, XAI explanations)
-- Tables: risk_scores, risk_explanations
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- Table: risk_scores
-- Purpose: Lưu kết quả tính toán risk score từ AI model
-- Frequency: Tính định kỳ (6h hoặc 24h)
-- ============================================================================
CREATE TABLE IF NOT EXISTS risk_scores (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id INT REFERENCES devices(id) ON DELETE SET NULL,
    
    -- Score
    calculated_at TIMESTAMPTZ NOT NULL,
    risk_type VARCHAR(50) NOT NULL CHECK (risk_type IN ('stroke', 'heartattack', 'afib', 'general')),
    score DECIMAL(5,2) NOT NULL CHECK (score >= 0 AND score <= 100),  -- 0.00 - 100.00
    risk_level VARCHAR(20) CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
    
    -- Input Features (for reproducibility & explainability)
    features JSONB NOT NULL,
    /* Example:
    {
        "avg_hr_24h": 85,
        "hrv_sdnn": 30,
        "low_spo2_events": 5,
        "age": 65,
        "has_hypertension": true,
        "bmi": 28.5
    }
    */
    
    -- Model Info
    model_version VARCHAR(20),
    algorithm VARCHAR(50),  -- 'random_forest', 'neural_network', 'gradient_boosting'
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE risk_scores IS 'Bảng lưu kết quả tính toán risk score từ AI model';
COMMENT ON COLUMN risk_scores.risk_type IS 'Loại rủi ro: stroke (đột quỵ), heartattack (nhồi máu cơ tim), afib (rung nhĩ)';
COMMENT ON COLUMN risk_scores.score IS 'Điểm rủi ro (0-100)';
COMMENT ON COLUMN risk_scores.risk_level IS 'Mức độ: low, medium, high, critical';
COMMENT ON COLUMN risk_scores.features IS 'Input features dạng JSONB (để reproduce & explain)';

-- ============================================================================
-- Table: risk_explanations
-- Purpose: Explainable AI (XAI) - giải thích tại sao risk score cao
-- ============================================================================
CREATE TABLE IF NOT EXISTS risk_explanations (
    id SERIAL PRIMARY KEY,
    risk_score_id INT NOT NULL REFERENCES risk_scores(id) ON DELETE CASCADE,
    
    -- Explanation (Natural Language)
    explanation_text TEXT NOT NULL,
    /* Example:
    "Nguy cơ cao do nhịp tim tăng vọt 120bpm khi đang nghỉ ngơi 
     và HRV thấp bất thường (25ms). Khuyến nghị kiểm tra y tế."
    */
    
    -- Feature Importance (for visualization)
    feature_importance JSONB,
    /* Example:
    {
        "low_hrv": 0.45,          // Most important
        "high_resting_hr": 0.30,
        "age": 0.15,
        "low_spo2": 0.10
    }
    */
    
    -- XAI Method
    xai_method VARCHAR(50) CHECK (xai_method IN ('shap', 'lime', 'rule_based', 'permutation')),
    
    -- Actionable Recommendations
    recommendations TEXT[],
    /* Example:
    ARRAY[
        'Nghỉ ngơi đầy đủ, ngủ 7-8 giờ/ngày',
        'Uống đủ nước (2 lít/ngày)',
        'Liên hệ bác sĩ nếu triệu chứng kéo dài > 48h'
    ]
    */
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE risk_explanations IS 'Bảng giải thích AI (XAI) - tại sao risk score cao';
COMMENT ON COLUMN risk_explanations.explanation_text IS 'Giải thích bằng ngôn ngữ tự nhiên (tiếng Việt)';
COMMENT ON COLUMN risk_explanations.feature_importance IS 'Ranking features theo độ ảnh hưởng (0-1)';
COMMENT ON COLUMN risk_explanations.xai_method IS 'Phương pháp XAI: SHAP, LIME, rule-based';
COMMENT ON COLUMN risk_explanations.recommendations IS 'Khuyến nghị hành động cụ thể (array)';

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created table: risk_scores';
    RAISE NOTICE '✓ Created table: risk_explanations';
END $$;
