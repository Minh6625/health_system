-- ============================================================================
-- File: 10_insert_test_vitals_user1.sql
-- Purpose: Insert test device + vitals data for user_id = 1
-- ============================================================================

-- Step 1: Create test device for user_id = 1 (if not exists)
INSERT INTO devices (user_id, device_name, device_type, model, firmware_version, mac_address, serial_number, is_active, battery_level, last_sync_at)
VALUES (
    1,  -- user_id
    'Apple Watch Series 8',
    'smartwatch',
    'Series 8',
    '9.1',
    'AA:BB:CC:DD:EE:FF',
    'SERIAL123456',
    true,
    92,
    NOW()
)
ON CONFLICT DO NOTHING
RETURNING id;

-- Step 2: Get the device_id (for user_id = 1)
-- Note: If you need to know the device_id, run this separately:
-- SELECT id FROM devices WHERE user_id = 1 LIMIT 1;

-- Step 3: Insert vitals data for the last 24 hours (for device_id from step 1)
-- Assuming device_id for user_id = 1 (you may need to adjust this)
WITH device_lookup AS (
    SELECT id FROM devices WHERE user_id = 1 ORDER BY id DESC LIMIT 1
)
INSERT INTO vitals (time, device_id, heart_rate, spo2, temperature, blood_pressure_sys, blood_pressure_dia, hrv, respiratory_rate, signal_quality, motion_artifact)
SELECT 
    NOW() - INTERVAL '1 minute' * (ROW_NUMBER() OVER (ORDER BY GENERATE_SERIES(0, 100))),
    (SELECT id FROM device_lookup),
    65 + FLOOR(RANDOM() * 30),  -- heart_rate: 65-95 BPM
    97 + FLOOR(RANDOM() * 3),   -- spo2: 97-100%
    36.5 + (RANDOM() * 1.5),    -- temperature: 36.5-38°C
    120 + FLOOR(RANDOM() * 30), -- blood_pressure_sys: 120-150 mmHg
    75 + FLOOR(RANDOM() * 20),  -- blood_pressure_dia: 75-95 mmHg
    50 + FLOOR(RANDOM() * 30),  -- hrv: 50-80 ms
    16 + FLOOR(RANDOM() * 8),   -- respiratory_rate: 16-24 breaths/min
    85 + FLOOR(RANDOM() * 15),  -- signal_quality: 85-100%
    false                         -- motion_artifact: false
FROM GENERATE_SERIES(1, 100);

-- Step 4: Verify insertion
SELECT 
    d.id as device_id,
    d.user_id,
    COUNT(v.time) as vitals_count,
    MAX(v.time) as latest_vital_time
FROM devices d
LEFT JOIN vitals v ON d.id = v.device_id
WHERE d.user_id = 1
GROUP BY d.id, d.user_id;

RAISE NOTICE '✓ Test device + vitals inserted for user_id = 1';
