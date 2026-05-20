-- Phase 3: primary_device_id pointer on users.
--
-- Multi-device ownership stays first-class (vitals.device_id is
-- unchanged, every device a user pairs keeps streaming into the same
-- hypertable). This pointer just tells the dashboard / latest-vitals
-- query which single device should drive the UI when a user has more
-- than one paired source.
--
-- ON DELETE SET NULL: if the chosen device is later soft-deleted /
-- unpaired, the user row stays alive and the dashboard transparently
-- falls back to the legacy "latest-of-all" behaviour until the user
-- picks another primary.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS primary_device_id INTEGER
        REFERENCES devices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_users_primary_device_id
    ON users (primary_device_id)
    WHERE primary_device_id IS NOT NULL;

COMMENT ON COLUMN users.primary_device_id IS
    'Phase 3: pointer to the single device whose readings drive the dashboard. NULL = no preference (UI falls back to latest-of-all).';
