-- Migration: add_sleep_unique_constraint
-- Purpose: Prevent duplicate sleep sessions per user+device+date
-- Idempotent: safe to run multiple times
-- Fix: Using plain DATE column (not GENERATED) because start_time is TIMESTAMPTZ
--      GENERATED ALWAYS AS (start_time::date) fails with "not immutable" error.
--      Backend telemetry.py must explicitly set sleep_date from payload.date.

-- Step 1: Add plain sleep_date column (no GENERATED — not immutable with TIMESTAMPTZ)
ALTER TABLE sleep_sessions
  ADD COLUMN IF NOT EXISTS sleep_date DATE;

-- Step 2: Add unique index
CREATE UNIQUE INDEX IF NOT EXISTS uq_sleep_user_device_date
  ON sleep_sessions (user_id, device_id, sleep_date);
