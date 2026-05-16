-- ============================================================================
-- Migration: 20260516 — imu_windows hypertable + fall_events FK link
-- ADR-022 (IMU Window Persistence — OQ2) / Phase 7 redesign Slice 8.
--
-- Goal:
--   Persist the raw IMU window the simulator/mobile pushes to
--   POST /api/v1/mobile/telemetry/imu-window so admin web can replay
--   false-positive cases and the dataset is available for retrain.
--   Bounded growth via TimescaleDB native retention (7 days) +
--   compression policy (1 day) per ADR-022 Option A.
--
-- Approach:
--   * Surrogate ``id SERIAL`` + composite PK ``(id, time)`` — matches the
--     ``audit_logs`` hypertable pattern (init_full_setup.sql section
--     time-series). The ``time`` column MUST sit in the PK because
--     TimescaleDB requires the partitioning column to appear in every
--     unique constraint on the hypertable.
--   * Indexes:
--       - ``(device_id, time DESC)`` — primary query path
--         (admin web fall detail page, history scan).
--       - ``(fall_event_id) WHERE fall_event_id IS NOT NULL`` — partial
--         index for the join back to ``fall_events`` (only ~1 in 1000
--         windows actually carry a fall event id).
--   * Compression: segment by ``device_id``, order by ``time DESC``
--     (most-recent-first scan pattern).
--   * Retention: drop chunks older than 7 days.
--   * ``fall_events`` gets a composite FK ``(imu_window_id,
--     imu_window_time) -> imu_windows(id, time)`` so the join is
--     enforceable on the hypertable (single-column FK is not legal
--     against a hypertable PK that includes ``time``).
--
-- Idempotency:
--   Wrapped in ``CREATE TABLE IF NOT EXISTS`` / ``IF NOT EXISTS`` clauses
--   so re-running on an already-migrated DB is a no-op.
--
-- Rollback:
--   See bottom of file (commented). Drops ``imu_windows`` and the FK
--   columns on ``fall_events`` in reverse order.
-- ============================================================================

BEGIN;

-- 1. Table -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS imu_windows (
    id BIGSERIAL,
    time TIMESTAMPTZ NOT NULL,
    device_id INT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    fall_event_id INT REFERENCES fall_events(id) ON DELETE SET NULL,

    -- Raw signal — accel/gyro arrays of {x,y,z} samples + optional
    -- orientation pitch/roll/yaw. JSONB keeps the model-api payload
    -- shape verbatim so replay is exact.
    accel JSONB NOT NULL,
    gyro JSONB NOT NULL,
    orientation JSONB,

    -- Window metadata — sample rate + duration so consumers can replot
    -- without recomputing from timestamps. Defaults match the
    -- model-api ``fall_sampling_rate`` (50 Hz) and the IMU sample size
    -- (100 samples at 50 Hz ≈ 2.0 seconds).
    sample_rate_hz INT NOT NULL DEFAULT 50 CHECK (sample_rate_hz > 0 AND sample_rate_hz <= 200),
    duration_seconds REAL NOT NULL DEFAULT 2.0 CHECK (duration_seconds > 0 AND duration_seconds <= 60),

    -- Free-form scenario tag the simulator attaches: scenario_id,
    -- variant, activity_before, model_request_id for trace-back to the
    -- model-api inference. Always optional — production mobile may not
    -- send any of these.
    context JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Hypertable --------------------------------------------------------------
-- ``chunk_time_interval=1 day`` matches the cadence of fall events and
-- the retention boundary (so dropping a 7-day chunk drops exactly one
-- day of windows).
SELECT create_hypertable(
    'imu_windows',
    'time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- 3. Primary key + indexes ---------------------------------------------------
-- Composite PK so TimescaleDB accepts it; the surrogate ``id`` lets
-- ``fall_events.imu_window_id`` stay a single BIGINT in code paths that
-- only need the row pointer.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'imu_windows'::regclass
          AND contype = 'p'
    ) THEN
        ALTER TABLE imu_windows ADD PRIMARY KEY (id, time);
    END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_imu_windows_device_time
    ON imu_windows (device_id, time DESC);

CREATE INDEX IF NOT EXISTS idx_imu_windows_fall_event
    ON imu_windows (fall_event_id)
    WHERE fall_event_id IS NOT NULL;

-- 4. Compression + retention policies ----------------------------------------
-- Compress chunks older than 1 day (rolling working set stays
-- uncompressed for fast write/read). Native TimescaleDB compression
-- typically reaches ~10:1 on JSONB time-series data.
ALTER TABLE imu_windows SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy(
    'imu_windows',
    INTERVAL '1 day',
    if_not_exists => TRUE
);

SELECT add_retention_policy(
    'imu_windows',
    INTERVAL '7 days',
    if_not_exists => TRUE
);

-- 5. fall_events FK link -----------------------------------------------------
ALTER TABLE fall_events
    ADD COLUMN IF NOT EXISTS imu_window_id BIGINT;

ALTER TABLE fall_events
    ADD COLUMN IF NOT EXISTS imu_window_time TIMESTAMPTZ;

COMMENT ON COLUMN fall_events.imu_window_id IS
    'ADR-022: surrogate id of the imu_windows row this event was derived from. Null when the event predates Phase 7 S8 or arrived without a raw window.';
COMMENT ON COLUMN fall_events.imu_window_time IS
    'ADR-022: matching imu_windows.time partition value — required by the composite FK because imu_windows is a hypertable.';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_fall_events_imu_window'
    ) THEN
        ALTER TABLE fall_events
            ADD CONSTRAINT fk_fall_events_imu_window
            FOREIGN KEY (imu_window_id, imu_window_time)
            REFERENCES imu_windows (id, time)
            ON DELETE SET NULL;
    END IF;
END$$;

-- 6. Table + column comments -------------------------------------------------
COMMENT ON TABLE imu_windows IS
    'ADR-022 Phase 7 S8: raw IMU window persistence for fall replay + retrain. TimescaleDB hypertable, 7-day retention, compress after 1 day.';
COMMENT ON COLUMN imu_windows.accel IS
    'Array of {x,y,z} accelerometer samples, JSONB. Length matches sample_rate_hz * duration_seconds.';
COMMENT ON COLUMN imu_windows.gyro IS
    'Array of {x,y,z} gyroscope samples, JSONB. Same length as accel.';
COMMENT ON COLUMN imu_windows.orientation IS
    'Optional array of {pitch,roll,yaw} orientation samples. May be null when the source device lacks a fused-orientation channel.';
COMMENT ON COLUMN imu_windows.context IS
    'Free-form metadata bag — scenario_id, variant, activity_before, model_request_id. Surfaced verbatim to the admin replay viewer.';

COMMIT;

-- ============================================================================
-- ROLLBACK (manual — uncomment to revert):
--
--   BEGIN;
--   ALTER TABLE fall_events DROP CONSTRAINT IF EXISTS fk_fall_events_imu_window;
--   ALTER TABLE fall_events DROP COLUMN IF EXISTS imu_window_time;
--   ALTER TABLE fall_events DROP COLUMN IF EXISTS imu_window_id;
--   SELECT remove_retention_policy('imu_windows', if_exists => TRUE);
--   SELECT remove_compression_policy('imu_windows', if_exists => TRUE);
--   DROP TABLE IF EXISTS imu_windows;
--   COMMIT;
-- ============================================================================
