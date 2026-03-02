-- ============================================================================
-- File: 05_create_tables_events_alerts.sql
-- Description: Tạo bảng cho events (fall, SOS) và alerts
-- Tables: fall_events, sos_events, alerts
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- Table: fall_events
-- Purpose: Lưu trữ các sự kiện té ngã được AI phát hiện
-- ============================================================================
CREATE TABLE IF NOT EXISTS fall_events (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    -- Detection
    detected_at TIMESTAMPTZ NOT NULL,
    confidence DECIMAL(4,3) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),  -- 0.000 - 1.000
    model_version VARCHAR(20),  -- For A/B testing different models
    
    -- Location (GPS)
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    location_accuracy REAL,  -- meters
    address TEXT,  -- Reverse geocoded address
    
    -- User Response Workflow
    user_notified_at TIMESTAMPTZ,
    user_responded_at TIMESTAMPTZ,
    user_cancelled BOOLEAN DEFAULT false,
    cancel_reason VARCHAR(255),
    
    -- SOS Status
    sos_triggered BOOLEAN DEFAULT false,
    sos_triggered_at TIMESTAMPTZ,
    
    -- AI Explainability (XAI)
    features JSONB,  -- Store input features for explainability
    -- Example: {"max_accel": 15.2, "impact_duration_ms": 250, "post_impact_motion": "low"}
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE fall_events IS 'Bảng lưu trữ các sự kiện té ngã được AI phát hiện';
COMMENT ON COLUMN fall_events.confidence IS 'Độ tin cậy từ AI model (0.000 - 1.000)';
COMMENT ON COLUMN fall_events.model_version IS 'Version của model (để so sánh performance giữa các versions)';
COMMENT ON COLUMN fall_events.user_cancelled IS 'True nếu user cancel trong 30 giây (false alarm)';
COMMENT ON COLUMN fall_events.features IS 'Input features cho XAI explanation (JSONB)';

-- ============================================================================
-- Table: sos_events
-- Purpose: Tracking các cuộc gọi cứu hộ khẩn cấp
-- ============================================================================
CREATE TABLE IF NOT EXISTS sos_events (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    
    -- Source
    fall_event_id INT REFERENCES fall_events(id) ON DELETE SET NULL,  -- NULL if manual SOS
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Trigger
    trigger_type VARCHAR(20) NOT NULL CHECK (trigger_type IN ('auto', 'manual')),
    triggered_at TIMESTAMPTZ NOT NULL,
    
    -- Location
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    address TEXT,
    
    -- Response Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'responded', 'cancelled', 'resolved')),
    resolved_at TIMESTAMPTZ,
    resolved_by_user_id INT REFERENCES users(id),  -- Who resolved it
    resolution_notes TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE sos_events IS 'Bảng tracking các cuộc gọi SOS khẩn cấp';
COMMENT ON COLUMN sos_events.trigger_type IS 'auto (từ fall detection) hoặc manual (user bấm nút SOS)';
COMMENT ON COLUMN sos_events.status IS 'active (đang xử lý), responded (đã nhận), cancelled, resolved (đã giải quyết)';

-- Add trigger for auto-update updated_at
CREATE TRIGGER update_sos_events_updated_at 
    BEFORE UPDATE ON sos_events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Table: alerts
-- Purpose: Central table cho TẤT CẢ notifications
-- ============================================================================
CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    
    -- Target (người nhận alert)
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id INT REFERENCES devices(id) ON DELETE SET NULL,
    
    -- Alert Type
    alert_type VARCHAR(50) NOT NULL CHECK (alert_type IN (
        'vital_abnormal',      -- SpO2 < 92%, HR > 120
        'fall_detected',       -- Té ngã
        'sos_triggered',       -- SOS khẩn cấp
        'device_offline',      -- Thiết bị mất kết nối
        'low_battery',         -- Pin dưới 20%
        'high_risk_score'      -- Risk score cao
    )),
    
    -- Content
    title VARCHAR(255) NOT NULL,
    message TEXT,
    severity VARCHAR(20) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    
    -- Related Entities
    fall_event_id INT REFERENCES fall_events(id) ON DELETE SET NULL,
    sos_event_id INT REFERENCES sos_events(id) ON DELETE SET NULL,
    
    -- Data Snapshot (store context at alert time)
    data JSONB,
    -- Example: {"heart_rate": 135, "spo2": 88, "battery": 15, "location": {...}}
    
    -- Delivery Status
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,  -- FCM/APNs confirmation
    read_at TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    
    -- Delivery Channels
    sent_via TEXT[] DEFAULT ARRAY['push'],  -- ['push', 'sms', 'email']
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ  -- Auto-cleanup old alerts
);

COMMENT ON TABLE alerts IS 'Bảng central cho tất cả notifications (push, SMS, email)';
COMMENT ON COLUMN alerts.alert_type IS 'Loại cảnh báo: vital_abnormal, fall_detected, sos_triggered, etc.';
COMMENT ON COLUMN alerts.severity IS 'Mức độ nghiêm trọng: low, medium, high, critical';
COMMENT ON COLUMN alerts.data IS 'JSONB snapshot dữ liệu tại thời điểm alert (để audit sau này)';
COMMENT ON COLUMN alerts.sent_via IS 'Array các kênh gửi: push, sms, email';

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created table: fall_events';
    RAISE NOTICE '✓ Created table: sos_events';
    RAISE NOTICE '✓ Created table: alerts';
END $$;
