-- ============================================================================
-- File: 07_create_tables_system.sql
-- Description: Tạo bảng cho system logs và metrics
-- Tables: audit_logs, system_metrics
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- Hypertable: audit_logs
-- Purpose: Ghi lại tất cả hành động quan trọng (compliance requirement)
-- Retention: 2 years
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL,
    time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Actor (who performed the action)
    user_id INT REFERENCES users(id) ON DELETE SET NULL,
    device_id INT REFERENCES devices(id) ON DELETE SET NULL,
    
    -- Action
    action VARCHAR(100) NOT NULL,  
    -- Examples: 'user.login', 'user.logout', 'alert.sent', 'data.exported', 'settings.changed'
    
    resource_type VARCHAR(50),  -- 'user', 'device', 'alert', 'vital'
    resource_id INT,
    
    -- Details (JSONB for flexibility)
    details JSONB,
    /* Example:
    {
        "old_value": {"email": "old@example.com"},
        "new_value": {"email": "new@example.com"},
        "ip_address": "192.168.1.100"
    }
    */
    
    -- Client Info
    ip_address INET,
    user_agent TEXT,
    
    -- Result
    status VARCHAR(20) CHECK (status IN ('success', 'failure', 'pending')),
    error_message TEXT
);

-- Convert to hypertable (partitioned by month)
SELECT create_hypertable('audit_logs', 'time', 
    chunk_time_interval => INTERVAL '1 month',
    if_not_exists => TRUE
);

-- Add primary key
ALTER TABLE audit_logs ADD PRIMARY KEY (id, time);

COMMENT ON TABLE audit_logs IS 'Hypertable audit logs - ghi lại tất cả hành động quan trọng (GDPR/HIPAA compliance)';
COMMENT ON COLUMN audit_logs.action IS 'Hành động: user.login, alert.sent, data.exported, etc.';
COMMENT ON COLUMN audit_logs.details IS 'Chi tiết hành động (JSONB để flexible)';

-- ============================================================================
-- Hypertable: system_metrics
-- Purpose: Monitor performance của hệ thống
-- ============================================================================
CREATE TABLE IF NOT EXISTS system_metrics (
    time TIMESTAMPTZ NOT NULL,
    
    -- Metric
    metric_name VARCHAR(100) NOT NULL,
    /* Examples:
    - 'mqtt.messages_received'
    - 'api.latency_ms'
    - 'db.connections_active'
    - 'ai.inference_time_ms'
    */
    
    value REAL NOT NULL,
    
    -- Dimensions (tags for filtering)
    tags JSONB,
    /* Example:
    {
        "service": "api",
        "endpoint": "/vitals",
        "status_code": 200,
        "region": "asia-southeast"
    }
    */
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Convert to hypertable
SELECT create_hypertable('system_metrics', 'time', 
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

-- Add composite primary key
ALTER TABLE system_metrics ADD PRIMARY KEY (metric_name, time);

COMMENT ON TABLE system_metrics IS 'Hypertable system metrics - monitor performance hệ thống';
COMMENT ON COLUMN system_metrics.metric_name IS 'Tên metric: mqtt.messages_received, api.latency_ms, etc.';
COMMENT ON COLUMN system_metrics.tags IS 'Dimensions để filter (service, endpoint, region, etc.)';

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created hypertable: audit_logs (1-month chunks)';
    RAISE NOTICE '✓ Created hypertable: system_metrics (7-day chunks)';
END $$;
