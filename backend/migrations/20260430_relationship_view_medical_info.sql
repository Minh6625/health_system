-- ============================================================================
-- Migration: Add can_view_medical_info permission to user_relationships
-- Date: 2026-04-30
-- Bug: P-4 — Caregivers/doctors cannot read patients' shared medical info
--
-- Why this column:
--   Patients already self-fill medical info (blood_type, height_cm, weight_kg,
--   medications[], allergies[], medical_conditions[]) via the mobile
--   ``MedicalInfoScreen`` whose copy already promises:
--       "Thông tin y tế chỉ được chia sẻ với bác sĩ hoặc người chăm sóc
--        được bạn ủy quyền."
--   But there was no plumbing to actually share it: no permission flag, no
--   API route, no caregiver-facing screen. The data was effectively a
--   black hole.
--
--   We model this consistently with the existing trio
--   (can_view_vitals / can_receive_alerts / can_view_location) — one bool
--   column on user_relationships, gated on the row where the *granter* is
--   the patient and the *grantee* is the caregiver.
--
-- Forward compatibility:
--   * Default FALSE so legacy relationships stay closed (privacy preserving)
--     until the patient explicitly toggles it on.
--   * NOT NULL with server default so ``UserRelationship(...)`` constructed
--     without an explicit value still inserts ``FALSE`` (matches the other
--     three permission columns' Python ``default=False``).
--   * IF NOT EXISTS makes the migration idempotent.
-- ============================================================================

ALTER TABLE user_relationships
    ADD COLUMN IF NOT EXISTS can_view_medical_info BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN user_relationships.can_view_medical_info IS
    'P-4: granter (patient_id) allows grantee (caregiver_id) to read the '
    'patient''s medical profile (blood type, height, weight, medications, '
    'allergies, medical conditions). Defaults FALSE so the privacy posture '
    'is opt-in. Read by RelationshipService.get_linked_contact_medical_info '
    'and surfaced in LinkedContactDetailResponse.permissions.';
