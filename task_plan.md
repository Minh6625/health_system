# Emergency SOS E2E Ship Plan

1. Audit current Emergency SOS code, tests, and release docs against the latest E2E gate.
   Verify: every required manual SOS and risk-escalation surface has a matching tracked test or explicit blocker.

2. Promote local Emergency SOS tests and helpers into the branch.
   Verify: missing `backend/tests`, `integration_test`, and `test/features/emergency` files are tracked and referenced by the release checklist.

3. Patch Emergency SOS production code only where the promoted tests reveal coverage gaps.
   Verify: code paths for manual SOS, caregiver resolve, realtime risk escalation, and auth replay match the tracked test expectations.

4. Refresh release evidence docs to reflect the strongest verifiable E2E state from this branch.
   Verify: checklist/status docs distinguish automated coverage from real-device blockers clearly.

5. Run every verification command available in this environment and record external blockers for the rest.
   Verify: command outputs are captured in the session; unresolved items are limited to environment/device constraints.

6. Commit the Emergency SOS E2E ship batch on the current branch.
   Verify: one commit contains the promoted tests, code fixes, and updated release docs.
