-- Migration: alert_type_alignment
-- Purpose:
--   Align the live `alerts.alert_type` CHECK constraint with the alert types
--   currently emitted by the backend risk/SOS/telemetry pipelines.

ALTER TABLE alerts
  DROP CONSTRAINT IF EXISTS alerts_alert_type_check;

ALTER TABLE alerts
  ADD CONSTRAINT alerts_alert_type_check
  CHECK (
    alert_type IN (
      'vital_abnormal',
      'vitals_threshold',
      'fall_detected',
      'fall_detection',
      'sos',
      'sos_triggered',
      'device_offline',
      'low_battery',
      'high_risk_score',
      'risk_high',
      'risk_critical',
      'generic_alert'
    )
  );
