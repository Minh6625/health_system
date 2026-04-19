-- Migration: risk_alert_escalation
-- Purpose:
--   1. Backfill existing risk_scores.risk_level values from high -> medium.
--   2. Tighten the risk_level check constraint to low|medium|critical.
--   3. Create a terminal response table for risk alert acknowledgements/escalations.

UPDATE risk_scores
SET risk_level = 'medium'
WHERE risk_level = 'high';

ALTER TABLE risk_scores
  DROP CONSTRAINT IF EXISTS check_risk_level;

ALTER TABLE risk_scores
  ADD CONSTRAINT check_risk_level
  CHECK (risk_level IN ('low', 'medium', 'critical'));

CREATE TABLE IF NOT EXISTS risk_alert_responses (
  id BIGSERIAL PRIMARY KEY,
  notification_id BIGINT NOT NULL UNIQUE REFERENCES alerts(id) ON DELETE CASCADE,
  response_action VARCHAR(32) NOT NULL,
  risk_score_id BIGINT NULL,
  source VARCHAR(32) NOT NULL,
  device_id BIGINT NULL,
  latitude DOUBLE PRECISION NULL,
  longitude DOUBLE PRECISION NULL,
  address TEXT NULL,
  responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sos_event_id BIGINT NULL REFERENCES sos_events(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT check_risk_alert_response_action
    CHECK (response_action IN ('safe', 'help_requested', 'timeout_escalated')),
  CONSTRAINT check_risk_alert_response_source
    CHECK (source IN ('overlay', 'push_tap'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_risk_alert_responses_notification_id
  ON risk_alert_responses (notification_id);
