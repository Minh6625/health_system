# Family Relationships E2E Ship Design

**Date:** 2026-04-23
**Branch:** `agent/family-relationship-ship`
**Status:** Approved for spec drafting, pending final user review

## Goal

Ship the Family / Relationships / Caregiver dashboard module with real data paths, bounded refactoring, and automated evidence strong enough to treat the module as E2E-ready.

This design covers:

- family shell tab behavior for dashboard, contacts, and caregiver SOS
- contact list loading and refresh
- search user and send request
- accept and reject request
- edit permissions, label, tags, and unlink
- linked contact detail
- caregiver dashboard snapshots used by family surfaces
- backend integration coverage for relationship CRUD and search
- Flutter widget and integration coverage for the family module

This design does **not** attempt:

- a redesign of the Family UI
- a rewrite of emergency infrastructure
- a new backend relationship model
- speculative abstractions for future sharing modes

The target is ship readiness for the current family feature set.

## Current-State Findings

### 1. Family state ownership is split between real providers and a singleton mock bridge

The module is currently half-real and half-mock.

Real data paths already exist in:

- [`lib/features/family/providers/family_dashboard_provider.dart`](../../../lib/features/family/providers/family_dashboard_provider.dart)
- [`lib/features/family/providers/linked_contact_detail_provider.dart`](../../../lib/features/family/providers/linked_contact_detail_provider.dart)
- [`lib/features/family/repositories/family_repository.dart`](../../../lib/features/family/repositories/family_repository.dart)

But core shell and contact flows still depend on the singleton mock bridge:

- [`lib/features/family/screens/family_shell_screen.dart`](../../../lib/features/family/screens/family_shell_screen.dart)
- [`lib/features/family/screens/contact_list_screen.dart`](../../../lib/features/family/screens/contact_list_screen.dart)
- [`lib/features/family/screens/add_contact_screen.dart`](../../../lib/features/family/screens/add_contact_screen.dart)
- [`lib/features/family/widgets/pending_request_card.dart`](../../../lib/features/family/widgets/pending_request_card.dart)
- [`lib/features/family/widgets/linked_contact_card.dart`](../../../lib/features/family/widgets/linked_contact_card.dart)
- [`lib/features/family/providers/shared_family_mock_provider.dart`](../../../lib/features/family/providers/shared_family_mock_provider.dart)

This split makes the module hard to reason about and is the main reason the feature is not E2E-shippable today.

### 2. The accept flow promises permission setup that the backend path does not actually persist

The UI asks the user to choose permissions in:

- [`lib/features/family/widgets/permission_setup_bottom_sheet.dart`](../../../lib/features/family/widgets/permission_setup_bottom_sheet.dart)

But the backend `accept` path currently auto-enables default permissions in:

- [`backend/app/services/relationship_service.py`](../../../backend/app/services/relationship_service.py)

The current mock bridge further hides failures by mutating local state optimistically:

- [`lib/features/family/providers/shared_family_mock_provider.dart`](../../../lib/features/family/providers/shared_family_mock_provider.dart)

As a result, the UX says "permission setup" while the durable system behavior is "accept first, patch later, maybe".

### 3. Add-contact still contains synthetic fallback behavior

`AddContactScreen` already calls real repository methods for search, request, accept, reject, and unlink, but still contains mock-oriented control flow:

- refresh through `SharedFamilyMockProvider`
- a synthetic fallback request using `targetUserId: 1`
- comments and navigation behavior tied to simulated QR success

Source:

- [`lib/features/family/screens/add_contact_screen.dart`](../../../lib/features/family/screens/add_contact_screen.dart)

This makes the flow non-deterministic and unsuitable as a reliable E2E entry point.

### 4. Caregiver dashboard snapshots are not fully real

The dashboard route exists:

- [`backend/app/api/routes/relationships.py`](../../../backend/app/api/routes/relationships.py)

And the service does return live vital baselines:

- [`backend/app/services/relationship_service.py`](../../../backend/app/services/relationship_service.py)

But it still hardcodes or omits the fields the family UI expects for shipping behavior:

- `risk_level` is always `"low"`
- `is_sos_active` is always `False`
- `is_pinned` is always `False`
- sleep and health-score fields are not sourced from real backend state

That means replacing the mock bridge alone is not enough. The family dashboard would still render an incomplete reality.

### 5. SOS tab entitlement is still hardcoded in the shell

The family shell currently forces the SOS tab on with:

- `_canReceiveAlerts = true`

Source:

- [`lib/features/family/screens/family_shell_screen.dart`](../../../lib/features/family/screens/family_shell_screen.dart)

The backend already exposes an `access-profiles` route:

- [`backend/app/api/routes/relationships.py`](../../../backend/app/api/routes/relationships.py)

But the mobile family module does not use it yet. Today the shell behavior is dev-friendly, not ship-safe.

### 6. Coverage is materially missing at the feature boundary

There is no direct Flutter family test suite under `test/features/family/`, and there is no family-specific integration test under `integration_test/`.

Backend also has no dedicated relationship contract suite. Existing evidence is only indirect through home, sleep, and risk flows.

Useful related evidence already exists in:

- [`integration_test/home_dashboard_real_device_e2e_test.dart`](../../../integration_test/home_dashboard_real_device_e2e_test.dart)
- [`integration_test/sleep_analysis_real_device_e2e_test.dart`](../../../integration_test/sleep_analysis_real_device_e2e_test.dart)
- [`backend/tests/test_e2e_analysis_risk_read_surfaces.py`](../../../backend/tests/test_e2e_analysis_risk_read_surfaces.py)

This existing evidence proves the repo can already exercise linked-profile behavior, but not the family module itself.

## Problems To Solve

1. One feature currently has two sources of truth: real repository state and mock singleton state.
2. Contact mutations are not consistently server-truth-driven after each action.
3. Accept flow semantics are weaker than the UX implies.
4. Caregiver dashboard data is not rich enough to support family tab badges, filters, and SOS affordances with real backend state.
5. SOS tab visibility is not derived from actual relationship/access rules.
6. The module lacks direct automated evidence at backend, widget, and integration levels.

## Design Principles

1. Keep the current route surface wherever possible. Prefer hardening over redesign.
2. Use the server as the source of truth after every mutation. No synthetic contact rows.
3. Keep refactors surgical. Remove only the mock code that blocks shipping.
4. Add tests before changing behavior where a contract is ambiguous.
5. Make automated evidence the blocking ship gate. Manual device checks remain valuable but secondary.

## Approaches Considered

### Approach A: Route-stable hardening with real providers

- keep the current relationship routes
- replace `SharedFamilyMockProvider` with a real relationship-list provider
- keep `POST /relationships/accept`, then immediately persist selected permissions and labels through `PUT /relationships/{relationship_id}`
- enrich dashboard snapshots without changing the mobile route surface

Pros:

- lowest contract churn
- uses existing repository methods
- fastest path to ship

Cons:

- accept plus update becomes a two-step mutation
- requires careful error handling for partial success

### Approach B: Extend `accept` to be atomic

- modify `POST /relationships/accept` so it accepts permissions and labels in one payload
- simplify the mobile accept flow accordingly

Pros:

- stronger semantic match between UX and backend contract
- no partial accept-then-update state

Cons:

- more backend contract churn
- higher risk to current route callers
- larger change set than needed for this ship pass

### Approach C: Keep the current shell and test around the mock bridge

- retain `SharedFamilyMockProvider`
- add tests over existing UI behavior

Pros:

- smallest code change

Cons:

- does not produce true E2E readiness
- preserves the main ship blocker
- likely creates false confidence

## Chosen Direction

Choose **Approach A** for this ship pass.

Rationale:

- It removes the blocking mock ownership without introducing a new backend API design.
- It allows us to reuse existing routes and repository code.
- It keeps the implementation bounded enough to finish with meaningful tests.
- It preserves the option to make `accept` atomic later if post-ship ergonomics demand it.

## Proposed Architecture

### A. Replace `SharedFamilyMockProvider` with a real relationship-list provider

Introduce a non-mock provider dedicated to relationship list ownership.

Responsibility:

- load relationship list from `/relationships`
- derive `pendingRequests` and `acceptedContacts`
- own contact-list refresh state and mutation state
- reload from server after send, accept, reject, cancel, update, and unlink

This provider replaces the singleton bridge as the source of truth for:

- `FamilyShellScreen` contact badge
- `ContactListScreen`
- `PendingRequestCard`
- `LinkedContactCard`
- `AddContactScreen` list refresh

The provider should not generate dashboard snapshots. That responsibility must stay with the dashboard/backend path.

### B. Keep dashboard ownership in `FamilyDashboardProvider`, but harden the backend snapshot contract

`FamilyDashboardProvider` is already the correct mobile boundary for dashboard data.

The backend route behind it must be enriched so family surfaces receive real:

- permission-gated tracking visibility
- risk level
- SOS active state and `sos_id`
- sleep summary fields
- health-score summary fields
- no-data messaging

This keeps the mobile API surface stable while making the response good enough for:

- dashboard cards
- dashboard filters
- shell badge counts
- person detail rendering
- SOS overlay behavior

### C. Keep linked contact detail on its own provider, but make all edits server-truth-driven

`LinkedContactDetailProvider` is already real, but it must participate in the same contract rules as the new relationship-list provider.

Required behavior:

- optimistic updates may exist only when immediately reversible
- the provider must surface mutation failure cleanly
- the parent list must refresh from server after returning from detail

This preserves separation of concerns:

- list provider owns list state
- detail provider owns one contact detail screen session

### D. Keep the current route surface for request, accept, update, and delete

For this pass, the backend API surface stays:

- `GET /relationships/dashboard`
- `GET /relationships/{contact_id}/detail`
- `GET /access-profiles`
- `GET /relationships/search`
- `GET /relationships`
- `POST /relationships/request`
- `POST /relationships/accept`
- `PUT /relationships/{relationship_id}`
- `DELETE /relationships/{relationship_id}`

Contract rule for mobile:

- request uses `POST /relationships/request`
- accept uses `POST /relationships/accept`
- selected permissions, tags, and primary label are then persisted with `PUT /relationships/{relationship_id}`
- reject, cancel, and unlink use `DELETE /relationships/{relationship_id}`

Contract rule for backend:

- if `accept` succeeds and the follow-up `update` fails, the client must report partial completion and allow repair in detail settings
- tests must cover this sequence explicitly

### E. Drive shell SOS entitlement from real access data

The family shell should stop hardcoding SOS availability.

The shell must derive tab visibility from real access/relationship state, using either:

- `GET /access-profiles`, or
- the loaded relationship list if it contains enough information

The preferred source for this pass is `access-profiles`, because it already represents view/alert/location access in a shell-friendly way.

## Backend Changes

### Required for ship

1. Add direct contract coverage for search, request, accept, update, delete, dashboard, and detail.
2. Harden `request_relationship()` duplicate and self-target handling through tests.
3. Keep `accept_relationship()` as the accept step, but make the accept-plus-update sequence testable and explicit.
4. Enrich `get_dashboard_snapshots()` to derive:
   - risk level
   - SOS state
   - `sos_id`
   - sleep summary
   - health-score summary
5. Ensure detail and dashboard remain permission-aware.

### Not required for this ship pass

- introducing a new relationship table shape
- redesigning `RelationshipResponse`
- replacing the bidirectional row model

## Mobile Changes

### Required for ship

1. Remove runtime dependence on `SharedFamilyMockProvider` from shell, contact list, add-contact, and contact cards.
2. Remove synthetic contact creation after request send.
3. Remove synthetic QR fallback request using dummy target IDs.
4. Ensure contact actions refresh from server truth after mutation.
5. Ensure accept flow persists selected permissions and labels through the real route sequence.
6. Replace hardcoded SOS tab entitlement with real access-derived behavior.
7. Preserve existing dashboard and detail UX where data is already represented correctly.

### Allowed cleanup during implementation

- delete `family_dashboard_mock_provider.dart`
- delete `linked_contact_detail_mock_provider.dart`
- delete `mock/contact_mock_data.dart`
- rename provider classes to remove `Mock` naming once all consumers are migrated

### Explicitly out of scope

- visual redesign of family cards
- large widget extraction refactors unrelated to shipping

## Test Strategy

## Blocking backend gates

Add dedicated backend tests for:

1. `search` returns connection status and relationship metadata correctly.
2. `request` rejects self and duplicate requests.
3. `accept` changes pending to accepted and creates the inverse accepted row.
4. `update` changes permissions, tags, and primary label for authorized users only.
5. `delete` handles reject, cancel, and unlink semantics.
6. `dashboard` returns permission-aware caregiver snapshots with real risk and SOS fields.
7. `detail` returns the expected linked contact contract for accepted relationships only.

These should live in new relationship-focused test files rather than being hidden inside unrelated E2E suites.

## Blocking Flutter gates

Add family-specific Flutter tests for:

1. `FamilyShellScreen` tab composition and badges under real provider state.
2. `ContactListScreen` loading, empty, error, refresh, and grouped rendering.
3. `AddContactScreen` search and request flows without synthetic fallback.
4. accept and reject actions from search results and pending requests.
5. `LinkedContactDetailScreen` permission toggles, label update, tag update, and unlink.
6. caregiver SOS tab visibility derived from real access state.

## Blocking integration gate

Add one direct family integration flow covering the user-facing module boundary:

1. login as caregiver
2. open family shell
3. inspect dashboard tab
4. inspect contact list
5. search or open an existing linked user
6. navigate to linked contact detail
7. edit permissions or labels
8. verify the shell and list refresh from real data

The existing real-device harnesses for home and sleep may be reused where they already establish caregiver auth and linked-profile state.

## Ship Blockers By Priority

### Immediate blockers

1. `SharedFamilyMockProvider` still owns live contact state.
2. accept flow does not durably match the permission-setup UX.
3. add-contact still contains synthetic fallback behavior.
4. dashboard snapshots do not provide real risk/SOS/sleep/score data.
5. shell SOS tab entitlement is hardcoded.
6. there is no direct family backend or Flutter test coverage.

### Important but parallelizable

1. add relationship contract tests
2. add dashboard snapshot enrichment
3. migrate shell/contact/add-contact consumers to the real list provider
4. add Flutter family tests

### Cleanup after core path is green

1. delete zombie mock providers and snapshot data
2. rename remaining mock-flavored types
3. simplify detail route fallback logic if still needed

## Acceptance Criteria

The module is considered shippable only when all of the following are true:

1. A caregiver can open Family and see dashboard data sourced from real backend state.
2. A caregiver can open the contact list and see real pending and accepted relationships.
3. Search and request use the live backend path only.
4. Accept and reject mutate durable backend state and the UI refreshes from server truth.
5. Permission, tag, label, and unlink changes persist and survive screen reload.
6. Linked contact detail renders from the live detail route.
7. SOS tab visibility is based on real access state, not a hardcoded flag.
8. Backend relationship tests pass.
9. Flutter family tests pass.
10. A direct family integration flow passes in the current environment, or any remaining real-device-only gap is explicitly documented as external.

## Risks And Mitigations

### Risk: two-step accept can partially succeed

Mitigation:

- make the client treat accept and follow-up update as one orchestrated flow
- add backend and Flutter tests for partial failure handling
- allow recovery through linked contact detail settings

### Risk: dashboard enrichment touches adjacent monitoring, risk, and emergency data paths

Mitigation:

- keep the route surface stable
- add backend tests before changing service logic
- patch only the fields the family module actually uses

### Risk: family shell auto-refresh causes test flakiness

Mitigation:

- add controllable refresh hooks or disable flags for tests where needed
- keep production behavior unchanged by default

## Environment Notes

Worktree setup for this spec was completed in:

- [family-relationship-ship](/mnt/d/doan2/vsmartwatch/health_system/.worktrees/family-relationship-ship)

Baseline notes from this environment:

- Flutter toolchain is available.
- Backend local `pytest` runtime is not currently available from the worktree by default.

That environment gap is not a design blocker, but it must be resolved or explicitly documented before claiming full backend verification later.

## Recommended Next Step

After user review of this spec:

1. write the implementation plan in `docs/superpowers/plans/`
2. break execution into backend contracts, mobile provider migration, and family test coverage
3. implement with TDD and verification gates
