-- ============================================================================
-- File: 04_create_tables_timeseries.sql
-- Description: Tạo hypertables cho dữ liệu time-series (vitals, motion)
-- Tables: vitals, motion_data
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- Hypertable: vitals
-- Purpose: Lưu trữ dữ liệu chỉ số sinh tồn theo thời gian thực
-- Frequency: 1 record/second/device
-- Retention: 1 year (with compression after 7 days)
-- ============================================================================
CREATE TABLE IF NOT EXISTS vitals (
    time TIMESTAMPTZ NOT NULL,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    -- Vital Signs
    heart_rate SMALLINT CHECK (heart_rate > 0 AND heart_rate < 300),  -- BPM (beats per minute)
    spo2 DECIMAL(4,2) CHECK (spo2 >= 0 AND spo2 <= 100),  -- % (0-100)
    temperature DECIMAL(4,2) CHECK (temperature > 30 AND temperature < 45),  -- Celsius
    
    -- Derived Metrics
    hrv SMALLINT,  -- Heart Rate Variability (ms)
    respiratory_rate SMALLINT CHECK (respiratory_rate >= 0 AND respiratory_rate < 100),  -- Breaths per minute
    
    -- Quality Indicators
    signal_quality SMALLINT CHECK (signal_quality >= 0 AND signal_quality <= 100),  -- PPG signal quality (0-100)
    motion_artifact BOOLEAN DEFAULT false,  -- True if motion detected during measurement
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Convert to hypertable (TimescaleDB magic!)
-- Partition by time with 7-day chunks
SELECT create_hypertable('vitals', 'time', 
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

-- Add composite primary key
ALTER TABLE vitals ADD PRIMARY KEY (device_id, time);

COMMENT ON TABLE vitals IS 'Hypertable lưu trữ chỉ số sinh tồn (heart rate, SpO2, temperature) - 1 record/giây';
COMMENT ON COLUMN vitals.heart_rate IS 'Nhịp tim (BPM - beats per minute)';
COMMENT ON COLUMN vitals.spo2 IS 'Độ bão hòa oxy trong máu (%, 0-100)';
COMMENT ON COLUMN vitals.hrv IS 'Heart Rate Variability - biến thiên nhịp tim (ms)';
COMMENT ON COLUMN vitals.signal_quality IS 'Chất lượng tín hiệu PPG (0-100), < 50 = unreliable';
COMMENT ON COLUMN vitals.motion_artifact IS 'True nếu phát hiện chuyển động khi đo (có thể ảnh hưởng độ chính xác)';

-- ============================================================================
-- Hypertable: motion_data
-- Purpose: Lưu dữ liệu cảm biến chuyển động cho fall detection AI
-- Frequency: 50-100 records/second/device (high frequency!)
-- Retention: 3 months (with compression after 3 days)
-- ============================================================================
CREATE TABLE IF NOT EXISTS motion_data (
    time TIMESTAMPTZ NOT NULL,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    
    -- Accelerometer (gia tốc 3 trục, m/s²)
    accel_x REAL,
    accel_y REAL,
    accel_z REAL,
    
    -- Gyroscope (con quay hồi chuyển, rad/s)
    gyro_x REAL,
    gyro_y REAL,
    gyro_z REAL,
    
    -- Derived
    magnitude REAL,  -- Pre-computed: sqrt(accel_x² + accel_y² + accel_z²)
    
    -- Metadata
    sampling_rate SMALLINT DEFAULT 50 CHECK (sampling_rate > 0 AND sampling_rate <= 200)  -- Hz
);

-- Convert to hypertable with 1-day chunks (high volume data)
SELECT create_hypertable('motion_data', 'time', 
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Add composite primary key
ALTER TABLE motion_data ADD PRIMARY KEY (device_id, time);

COMMENT ON TABLE motion_data IS 'Hypertable lưu dữ liệu cảm biến chuyển động (accelerometer, gyroscope) - 50-100 records/giây';
COMMENT ON COLUMN motion_data.accel_x IS 'Gia tốc trục X (m/s²)';
COMMENT ON COLUMN motion_data.accel_y IS 'Gia tốc trục Y (m/s²)';
COMMENT ON COLUMN motion_data.accel_z IS 'Gia tốc trục Z (m/s²)';
COMMENT ON COLUMN motion_data.magnitude IS 'Độ lớn vector gia tốc (pre-computed để tránh tính lại khi query)';
COMMENT ON COLUMN motion_data.sampling_rate IS 'Tần số lấy mẫu (Hz), thường 50-100';

-- ============================================================================
-- Create Continuous Aggregates (auto-downsampling)
-- Purpose: Pre-compute aggregates để query nhanh hơn
-- ============================================================================

-- 5-minute aggregates (for app charts)
CREATE MATERIALIZED VIEW IF NOT EXISTS vitals_5min
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('5 minutes', time) AS bucket,
    device_id,
    AVG(heart_rate) AS avg_hr,
    MIN(heart_rate) AS min_hr,
    MAX(heart_rate) AS max_hr,
    STDDEV(heart_rate) AS std_hr,  -- For HRV calculation
    AVG(spo2) AS avg_spo2,
    MIN(spo2) AS min_spo2,
    AVG(temperature) AS avg_temp,
    COUNT(*) AS sample_count
FROM vitals
GROUP BY bucket, device_id;

COMMENT ON MATERIALIZED VIEW vitals_5min IS 'Continuous aggregate: vitals theo 5 phút (dùng cho charts trong app)';

-- Hourly aggregates (for history view)
CREATE MATERIALIZED VIEW IF NOT EXISTS vitals_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    device_id,
    AVG(heart_rate) AS avg_hr,
    MIN(heart_rate) AS min_hr,
    MAX(heart_rate) AS max_hr,
    AVG(spo2) AS avg_spo2,
    MIN(spo2) AS min_spo2,
    AVG(temperature) AS avg_temp,
    COUNT(*) AS sample_count
FROM vitals
GROUP BY bucket, device_id;

COMMENT ON MATERIALIZED VIEW vitals_hourly IS 'Continuous aggregate: vitals theo giờ (dùng cho lịch sử 1 tuần, 1 tháng)';

-- Daily aggregates (for long-term trends)
CREATE MATERIALIZED VIEW IF NOT EXISTS vitals_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', time) AS bucket,
    device_id,
    AVG(heart_rate) AS avg_hr,
    MIN(heart_rate) AS min_hr,
    MAX(heart_rate) AS max_hr,
    AVG(spo2) AS avg_spo2,
    MIN(spo2) AS min_spo2,
    AVG(temperature) AS avg_temp,
    COUNT(*) AS sample_count
FROM vitals
GROUP BY bucket, device_id;

COMMENT ON MATERIALIZED VIEW vitals_daily IS 'Continuous aggregate: vitals theo ngày (dùng cho trends dài hạn)';

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created hypertable: vitals (7-day chunks)';
    RAISE NOTICE '✓ Created hypertable: motion_data (1-day chunks)';
    RAISE NOTICE '✓ Created continuous aggregate: vitals_5min';
    RAISE NOTICE '✓ Created continuous aggregate: vitals_hourly';
    RAISE NOTICE '✓ Created continuous aggregate: vitals_daily';
    RAISE NOTICE '→ Aggregates will auto-refresh based on policies (setup in 09_create_policies.sql)';
END $$;
