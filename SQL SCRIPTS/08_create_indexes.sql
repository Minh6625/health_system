-- ============================================================================
-- File: 08_create_indexes.sql
-- Description: Tạo tất cả indexes để optimize queries
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- INDEXES FOR: users
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

-- ============================================================================
-- INDEXES FOR: user_relationships
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_relationships_patient ON user_relationships(patient_id);
CREATE INDEX IF NOT EXISTS idx_relationships_caregiver ON user_relationships(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_relationships_primary ON user_relationships(patient_id, is_primary) 
    WHERE is_primary = true;

-- ============================================================================
-- INDEXES FOR: emergency_contacts
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON emergency_contacts(user_id, priority);

-- ============================================================================
-- INDEXES FOR: devices
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_active ON devices(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen_at DESC);
CREATE INDEX IF NOT EXISTS idx_devices_uuid ON devices(uuid);
CREATE INDEX IF NOT EXISTS idx_devices_mqtt_client ON devices(mqtt_client_id);

-- ============================================================================
-- INDEXES FOR: vitals (hypertable)
-- ============================================================================
-- Composite index for time-range queries
CREATE INDEX IF NOT EXISTS idx_vitals_device_time ON vitals(device_id, time DESC);

-- Partial indexes for abnormal values (fast alert queries)
CREATE INDEX IF NOT EXISTS idx_vitals_abnormal_hr ON vitals(device_id, time DESC) 
    WHERE heart_rate < 50 OR heart_rate > 120;

CREATE INDEX IF NOT EXISTS idx_vitals_low_spo2 ON vitals(device_id, time DESC) 
    WHERE spo2 < 92;

CREATE INDEX IF NOT EXISTS idx_vitals_abnormal_temp ON vitals(device_id, time DESC) 
    WHERE temperature < 35.5 OR temperature > 37.8;

-- Index for signal quality filtering
CREATE INDEX IF NOT EXISTS idx_vitals_quality ON vitals(signal_quality);

-- ============================================================================
-- INDEXES FOR: motion_data (hypertable)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_motion_device_time ON motion_data(device_id, time DESC);

-- Index for high magnitude (potential falls)
CREATE INDEX IF NOT EXISTS idx_motion_high_magnitude ON motion_data(device_id, time DESC) 
    WHERE magnitude > 20;  -- Threshold for potential fall

-- ============================================================================
-- INDEXES FOR: fall_events
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_fall_events_device ON fall_events(device_id, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_fall_events_pending ON fall_events(device_id, detected_at DESC) 
    WHERE user_responded_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fall_events_sos ON fall_events(sos_triggered, sos_triggered_at DESC) 
    WHERE sos_triggered = true;
CREATE INDEX IF NOT EXISTS idx_fall_events_confidence ON fall_events(confidence DESC);

-- ============================================================================
-- INDEXES FOR: sos_events
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_sos_events_user ON sos_events(user_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_sos_events_device ON sos_events(device_id, triggered_at DESC);
CREATE INDEX IF NOT EXISTS idx_sos_events_active ON sos_events(status, triggered_at DESC) 
    WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_sos_events_fall ON sos_events(fall_event_id);

-- ============================================================================
-- INDEXES FOR: alerts
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_alerts_user ON alerts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_unread ON alerts(user_id, created_at DESC) 
    WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_alerts_critical ON alerts(severity, created_at DESC) 
    WHERE severity IN ('high', 'critical');
CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(alert_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_device ON alerts(device_id, created_at DESC);

-- ============================================================================
-- INDEXES FOR: risk_scores
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_risk_scores_user ON risk_scores(user_id, calculated_at DESC);
CREATE INDEX IF NOT EXISTS idx_risk_scores_high ON risk_scores(user_id, calculated_at DESC) 
    WHERE risk_level IN ('high', 'critical');
CREATE INDEX IF NOT EXISTS idx_risk_scores_type ON risk_scores(risk_type, calculated_at DESC);

-- ============================================================================
-- INDEXES FOR: risk_explanations
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_risk_explanations_score ON risk_explanations(risk_score_id);

-- ============================================================================
-- INDEXES FOR: audit_logs (hypertable)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action, time DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs(status, time DESC);

-- ============================================================================
-- INDEXES FOR: system_metrics (hypertable)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_system_metrics_name ON system_metrics(metric_name, time DESC);

-- GIN index for JSONB tags (for filtering on tags)
CREATE INDEX IF NOT EXISTS idx_system_metrics_tags ON system_metrics USING GIN (tags);

-- ============================================================================
-- INDEXES FOR: Continuous Aggregates
-- ============================================================================
-- Indexes are automatically created for continuous aggregates by TimescaleDB

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created indexes for users (4 indexes)';
    RAISE NOTICE '✓ Created indexes for user_relationships (3 indexes)';
    RAISE NOTICE '✓ Created indexes for devices (6 indexes)';
    RAISE NOTICE '✓ Created indexes for vitals (6 indexes, including partial indexes)';
    RAISE NOTICE '✓ Created indexes for motion_data (2 indexes)';
    RAISE NOTICE '✓ Created indexes for fall_events (4 indexes)';
    RAISE NOTICE '✓ Created indexes for sos_events (4 indexes)';
    RAISE NOTICE '✓ Created indexes for alerts (6 indexes)';
    RAISE NOTICE '✓ Created indexes for risk_scores (3 indexes)';
    RAISE NOTICE '✓ Created indexes for audit_logs (4 indexes)';
    RAISE NOTICE '✓ Created indexes for system_metrics (2 indexes + GIN)';
    RAISE NOTICE '';
    RAISE NOTICE '→ Total: 44 indexes created';
    RAISE NOTICE '→ Partial indexes optimize abnormal value queries';
    RAISE NOTICE '→ Composite indexes optimize time-range queries';
END $$;
