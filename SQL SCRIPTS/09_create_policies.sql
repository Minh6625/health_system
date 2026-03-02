-- ============================================================================
-- File: 09_create_policies.sql
-- Description: Tạo compression, retention, và continuous aggregate policies
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- COMPRESSION POLICIES
-- Purpose: Tự động nén data cũ để tiết kiệm storage (90% reduction)
-- ============================================================================

-- Vitals: Compress sau 7 ngày
ALTER TABLE vitals SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('vitals', INTERVAL '7 days', if_not_exists => TRUE);

-- Motion Data: Compress sau 3 ngày (high volume)
ALTER TABLE motion_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('motion_data', INTERVAL '3 days', if_not_exists => TRUE);

-- Audit Logs: Compress sau 30 ngày
ALTER TABLE audit_logs SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'user_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('audit_logs', INTERVAL '30 days', if_not_exists => TRUE);

-- System Metrics: Compress sau 7 ngày
ALTER TABLE system_metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'metric_name',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('system_metrics', INTERVAL '7 days', if_not_exists => TRUE);

-- ============================================================================
-- RETENTION POLICIES
-- Purpose: Tự động xóa data cũ để quản lý storage
-- ============================================================================

-- Vitals: Xóa sau 1 năm (giữ aggregates)
SELECT add_retention_policy('vitals', INTERVAL '1 year', if_not_exists => TRUE);

-- Motion Data: Xóa sau 3 tháng (chỉ dùng cho inference, không cần lưu lâu)
SELECT add_retention_policy('motion_data', INTERVAL '3 months', if_not_exists => TRUE);

-- Audit Logs: Xóa sau 2 năm (compliance requirement)
SELECT add_retention_policy('audit_logs', INTERVAL '2 years', if_not_exists => TRUE);

-- System Metrics: Xóa sau 6 tháng
SELECT add_retention_policy('system_metrics', INTERVAL '6 months', if_not_exists => TRUE);

-- ============================================================================
-- CONTINUOUS AGGREGATE REFRESH POLICIES
-- Purpose: Tự động refresh materialized views
-- ============================================================================

-- vitals_5min: Refresh mỗi 5 phút
SELECT add_continuous_aggregate_policy('vitals_5min',
    start_offset => INTERVAL '1 hour',
    end_offset => INTERVAL '5 minutes',
    schedule_interval => INTERVAL '5 minutes',
    if_not_exists => TRUE
);

-- vitals_hourly: Refresh mỗi giờ
SELECT add_continuous_aggregate_policy('vitals_hourly',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- vitals_daily: Refresh mỗi ngày
SELECT add_continuous_aggregate_policy('vitals_daily',
    start_offset => INTERVAL '1 week',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- ============================================================================
-- VERIFY POLICIES
-- ============================================================================

-- Check compression policies
DO $$
DECLARE
    compression_count INT;
BEGIN
    SELECT COUNT(*) INTO compression_count
    FROM timescaledb_information.jobs
    WHERE proc_name = 'policy_compression';
    
    RAISE NOTICE '→ Compression policies created: %', compression_count;
END $$;

-- Check retention policies
DO $$
DECLARE
    retention_count INT;
BEGIN
    SELECT COUNT(*) INTO retention_count
    FROM timescaledb_information.jobs
    WHERE proc_name = 'policy_retention';
    
    RAISE NOTICE '→ Retention policies created: %', retention_count;
END $$;

-- Check continuous aggregate policies
DO $$
DECLARE
    cagg_count INT;
BEGIN
    SELECT COUNT(*) INTO cagg_count
    FROM timescaledb_information.jobs
    WHERE proc_name = 'policy_refresh_continuous_aggregate';
    
    RAISE NOTICE '→ Continuous aggregate refresh policies created: %', cagg_count;
END $$;

-- Print summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE 'POLICIES SUMMARY';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '';
    RAISE NOTICE 'COMPRESSION (auto compress old data):';
    RAISE NOTICE '  • vitals: after 7 days';
    RAISE NOTICE '  • motion_data: after 3 days';
    RAISE NOTICE '  • audit_logs: after 30 days';
    RAISE NOTICE '  • system_metrics: after 7 days';
    RAISE NOTICE '';
    RAISE NOTICE 'RETENTION (auto delete old data):';
    RAISE NOTICE '  • vitals: after 1 year';
    RAISE NOTICE '  • motion_data: after 3 months';
    RAISE NOTICE '  • audit_logs: after 2 years';
    RAISE NOTICE '  • system_metrics: after 6 months';
    RAISE NOTICE '';
    RAISE NOTICE 'CONTINUOUS AGGREGATES (auto refresh):';
    RAISE NOTICE '  • vitals_5min: every 5 minutes';
    RAISE NOTICE '  • vitals_hourly: every 1 hour';
    RAISE NOTICE '  • vitals_daily: every 1 day';
    RAISE NOTICE '';
    RAISE NOTICE '→ Expected storage savings: ~90%% after compression';
    RAISE NOTICE '→ Query performance: 10-100x faster with aggregates';
    RAISE NOTICE '';
    RAISE NOTICE '===============================================';
    RAISE NOTICE '✓ ALL POLICIES CONFIGURED SUCCESSFULLY!';
    RAISE NOTICE '===============================================';
END $$;

-- ============================================================================
-- ADDITIONAL PERFORMANCE TIPS
-- ============================================================================

-- Enable parallel query execution (if using PostgreSQL 14+)
-- Uncomment if your server has multiple CPU cores
-- ALTER DATABASE healthguard SET max_parallel_workers_per_gather = 4;

-- Increase work_mem for complex queries (adjust based on your RAM)
-- ALTER DATABASE healthguard SET work_mem = '64MB';

-- Enable JIT compilation for faster queries (PostgreSQL 11+)
-- ALTER DATABASE healthguard SET jit = on;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'OPTIONAL: For better performance, consider:';
    RAISE NOTICE '1. Enable parallel queries (max_parallel_workers_per_gather)';
    RAISE NOTICE '2. Increase work_mem for complex aggregations';
    RAISE NOTICE '3. Enable JIT compilation';
    RAISE NOTICE '';
    RAISE NOTICE 'See commented lines in this file for details.';
END $$;
