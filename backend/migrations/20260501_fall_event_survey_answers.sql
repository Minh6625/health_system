-- ============================================================================
-- Migration: Fall Lab Option 3-Lite — post-dismiss "stand-up" survey column
-- ============================================================================
-- Adds a JSONB column to ``fall_events`` so the mobile FallStandUpSurveyScreen
-- can persist its answer without inventing a new table.  Stays NULL when:
--   * The user did not respond to step 2 (pre-Option-3-Lite app build).
--   * The fall was a soft-alert (no SOS takeover, no survey shown).
--
-- Shape (all keys optional; survey is best-effort):
--   {
--     "can_stand": true | false | null,    -- null when user tapped "Bỏ qua"
--     "skipped":   true | false,           -- true when timer ran out
--     "answered_at": "2026-05-01T00:42:13Z"
--   }
--
-- The backend reads ``can_stand=false`` to fan out a softer follow-up alert
-- to caregivers ("patient said OK but cannot stand up"); the patient mobile
-- side does NOT escalate — that's the whole point of Option 3-Lite ("don't
-- punish a panicking elderly user").  See:
--   ``health_system/backend/app/services/push_notification_service.py::send_fall_followup_concern``
--   ``health_system/lib/features/fall/screens/fall_stand_up_survey_screen.dart``
-- ============================================================================

ALTER TABLE fall_events
    ADD COLUMN IF NOT EXISTS survey_answers JSONB;

COMMENT ON COLUMN fall_events.survey_answers IS
    'Option 3-Lite post-dismiss survey from FallStandUpSurveyScreen: '
    '{"can_stand": bool|null, "skipped": bool, "answered_at": iso}. '
    'NULL when user did not reach step 2 (or app version pre-survey).';
