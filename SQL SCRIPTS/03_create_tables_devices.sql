-- ============================================================================
-- File: 03_create_tables_devices.sql
-- Description: Tạo bảng quản lý thiết bị IoT
-- Tables: devices
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- ============================================================================
-- Table: devices
-- Purpose: Quản lý thiết bị IoT (smartwatch, fitness band)
-- ============================================================================
CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    uuid UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    
    -- Ownership
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Device Info
    device_name VARCHAR(100),
    device_type VARCHAR(50) DEFAULT 'smartwatch' CHECK (device_type IN ('smartwatch', 'fitness_band', 'medical_device')),
    model VARCHAR(100),
    firmware_version VARCHAR(20),
    
    -- Identification
    mac_address VARCHAR(17),  -- Format: AA:BB:CC:DD:EE:FF
    serial_number VARCHAR(100),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    battery_level SMALLINT CHECK (battery_level >= 0 AND battery_level <= 100),
    signal_strength SMALLINT,  -- RSSI value
    
    -- Connection
    last_seen_at TIMESTAMPTZ,
    last_sync_at TIMESTAMPTZ,
    mqtt_client_id VARCHAR(100),
    
    -- Calibration & Settings
    calibration_data JSONB,  -- Store sensor calibration parameters
    -- Example: {"heart_rate_offset": 0, "spo2_calibration": 1.02}
    
    -- Metadata
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ  -- Soft delete
);

COMMENT ON TABLE devices IS 'Bảng quản lý thiết bị IoT của người dùng';
COMMENT ON COLUMN devices.last_seen_at IS 'Timestamp lần cuối device gửi data (dùng để detect offline)';
COMMENT ON COLUMN devices.mqtt_client_id IS 'Client ID để map với MQTT messages';
COMMENT ON COLUMN devices.calibration_data IS 'Tham số hiệu chỉnh cảm biến (JSONB để flexible)';
COMMENT ON COLUMN devices.battery_level IS 'Mức pin (0-100%)';

-- Add trigger for auto-update updated_at
CREATE TRIGGER update_devices_updated_at 
    BEFORE UPDATE ON devices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ Created table: devices';
    RAISE NOTICE '✓ Added trigger for auto-update timestamps';
END $$;
