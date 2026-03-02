-- ============================================================================
-- File: 01_init_timescaledb.sql
-- Description: Khởi tạo TimescaleDB extension và cấu hình cơ bản
-- Author: HealthGuard Development Team
-- Date: 02/02/2026
-- ============================================================================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable other useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  -- For UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- For password hashing

-- Create custom types
DO $$ 
BEGIN
    -- User roles
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('patient', 'caregiver', 'admin');
    END IF;

    -- Alert severity
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alert_severity') THEN
        CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');
    END IF;

    -- SOS status
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sos_status') THEN
        CREATE TYPE sos_status AS ENUM ('active', 'responded', 'cancelled', 'resolved');
    END IF;

    -- Risk level
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'risk_level') THEN
        CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high', 'critical');
    END IF;
END $$;

-- Configure TimescaleDB
-- Set chunk time interval (default: 7 days for hypertables)
-- Will be applied when creating hypertables

-- Print confirmation
DO $$
BEGIN
    RAISE NOTICE '✓ TimescaleDB extension enabled successfully';
    RAISE NOTICE '✓ Supporting extensions enabled';
    RAISE NOTICE '✓ Custom types created';
    RAISE NOTICE '→ Ready to create tables';
END $$;
