# Notifications Full-Path Ship Design

**Date:** 2026-04-22
**Branch:** `TP/notifications`
**Status:** Approved for spec drafting, pending final user review

## Goal

Stabilize the full mobile notifications path so the project can ship the Notifications feature with strong automated evidence and a clear manual real-device checklist.

This design covers:

- push token register and unregister
- FCM foreground, background, and cold-start open flows
- websocket notification updates and catch-up after login
- notification inbox list, detail, search, pagination, and mark-as-read
- routing into SOS and risk flows from notification entry points

This design does **not** attempt a full rewrite of emergency or notification infrastructure. The target is ship readiness with bounded refactoring.

## Current-State Findings

### 1. Notification ownership is split across unrelated modules

Notification runtime behavior is currently concentrated in [`lib/features/emergency/services/sos_realtime_alert_service.dart`](../../../lib/features/emergency/services/sos_realtime_alert_service.dart), while inbox UI lives in [`lib/features/notifications/screens/notifications_screen.dart`](../../../lib/features/notifications/screens/notifications_screen.dart).

As a result, the Notifications feature is not truly a standalone module. It depends on emergency-specific orchestration for:

- Firebase Messaging initialization
- push-token sync and unregister
- websocket `/ws/notifications` handling
- local notification presentation
- open-from-notification routing
- missed-alert catch-up after login

### 2. Coverage is uneven

Backend already has risk-notification coverage in files such as:

- [`backend/tests/test_e2e_risk_notification.py`](../../../backend/tests/test_e2e_risk_notification.py)
- [`backend/tests/test_risk_escalation_flow.py`](../../../backend/tests/test_risk_escalation_flow.py)

Flutter coverage for the notification inbox is much thinner. The current direct notifications test file is mostly helper-focused:

- [`test/features/notifications/screens/notifications_screen_test.dart`](../../../test/features/notifications/screens/notifications_screen_test.dart)

There is some real-time notification behavior coverage in:

- [`test/features/emergency/services/sos_realtime_alert_service_flow_test.dart`](../../../test/features/emergency/services/sos_realtime_alert_service_flow_test.dart)

But the path is still not covered end-to-end at the feature boundary users experience as "Notifications".

### 3. Real-device verification is available but not a blocking gate for this pass

An Android device is available in the environment, but this pass will not block on a completed real-device run. Instead:

- the real-device scenarios will be designed and scaffolded
- automated verification will be the blocking ship gate
- manual real-device execution will remain a post-session checklist for the user

## Problems To Solve

1. The notification lifecycle is hard to reason about because runtime concerns and presentation concerns are mixed in one emergency-focused service.
2. Different entry points can drift in behavior:
   - push received in foreground
   - push tapped from tray
   - cold-start open
   - websocket update
   - inbox item tap
3. The inbox UI and the runtime service each contain notification classification logic, which increases mismatch risk.
4. The feature is difficult to verify because ownership boundaries do not match the user-facing feature boundary.

## Design Principles

1. Keep backend contracts stable unless tests prove a mismatch.
2. Refactor by extracting boundaries, not by rewriting everything.
3. Route every notification entry point through one normalization and decision path.
4. Keep SOS and critical-risk presentation behavior compatible with the current emergency UX.
5. Make automated verification the ship gate for this pass.

## Proposed Architecture

### A. `NotificationRuntime`

Responsibility:

- initialize and own mobile notification runtime concerns
- manage FCM permissions and lifecycle
- sync and unregister push tokens
- connect and react to `/ws/notifications`
- run missed-alert catch-up after login or reconnect

Inputs:

- `FirebaseMessaging.onMessage`
- `FirebaseMessaging.onMessageOpenedApp`
- `FirebaseMessaging.getInitialMessage()`
- websocket `/ws/notifications`
- auth state changes

Outputs:

- normalized notification events
- normalized open targets
- inbox refresh triggers

This extraction reduces the amount of lifecycle code inside the emergency service and gives the Notifications feature an explicit runtime owner.

### B. `NotificationOpenRouter`

Responsibility:

- normalize all notification payloads into one stable structure
- decide what screen or presenter should open
- ensure the same routing rules apply regardless of source

Supported source types:

- foreground push
- background push tap
- terminated-app launch
- websocket update
- local notification tap
- inbox item tap

Core routing rules:

- `risk_critical` -> critical risk target / overlay flow
- `risk_high` -> notifications inbox or notification detail flow
- `sos`, `manual`, `fall_detected`, `fall_detection` -> emergency flow
- non-emergency notifications -> inbox detail flow

This removes duplicated routing logic from multiple places and makes behavior testable from a single boundary.

### C. `NotificationInbox`

Responsibility:

- fetch list and detail from backend
- mark items as read
- support search, filters, pagination, and detail rendering
- render user-facing inbox behavior

This remains centered around [`lib/features/notifications/screens/notifications_screen.dart`](../../../lib/features/notifications/screens/notifications_screen.dart), but the screen should no longer own runtime routing concerns beyond opening what the router resolves.

### D. `Emergency Adapters`

Responsibility:

- present SOS and critical-risk UX that is already coupled to emergency flows
- keep full-screen alert presentation and risk-specific navigation behavior

This means the emergency module still owns emergency-specific UI, but it no longer owns the general mobile notification lifecycle.

## Data Model And Contracts

### Notification event normalization

All inbound payloads should be normalized to a single structure. The exact class name can change during implementation, but the shape should include:

- `source`
- `notificationId`
- `alertType`
- `riskLevel`
- `riskScoreId`
- `sosId`
- `title`
- `message`
- `createdAt`
- `isRead`
- `rawData`

### Open target normalization

A stable open target shape should be used for routing decisions:

- `type`
- `notificationId`
- `alertType`
- `riskLevel`
- `riskScoreId`
- `sosId`
- `title`
- `message`

This replaces ad hoc per-entry-point parsing and prevents route divergence.

### Backend contract stance

The current backend notification routes remain the baseline contract:

- [`backend/app/api/routes/notifications.py`](../../../backend/app/api/routes/notifications.py)
- [`backend/app/services/notification_service.py`](../../../backend/app/services/notification_service.py)
- [`backend/app/services/push_notification_service.py`](../../../backend/app/services/push_notification_service.py)

Planned rule for implementation:

- keep the routes stable by default
- add or modify backend tests first if a contract gap is discovered
- only patch backend behavior where failing tests prove a ship blocker

## Expected Architectural Changes Compared To Today

### What changes

- Notification lifecycle ownership moves out of a large emergency service into a notification-focused runtime layer.
- Routing rules are centralized instead of being split across runtime handlers and inbox UI.
- The inbox becomes a consumer of normalized notification behavior instead of being partially responsible for interpretation.
- Emergency keeps emergency presentation, not general notification lifecycle orchestration.

### What stays the same

- existing backend route surface remains substantially intact
- existing SOS and critical-risk UX stays compatible
- existing app bootstrap remains lightweight
- existing alert types and schemas remain the functional baseline

## Why This Is Better

1. It reduces coupling between Notifications and Emergency.
2. It creates one source of truth for notification routing.
3. It makes the feature easier to test near end-to-end without a device on every loop.
4. It localizes future notification changes to one runtime and one routing boundary.
5. It avoids a high-risk rewrite while still improving maintainability enough to support shipping.

## Testing Strategy

### Blocking automated gates

The implementation must satisfy these automated gates:

1. Backend notification contract tests pass.
2. Backend risk/SOS notification tests pass.
3. Flutter tests cover:
   - payload normalization
   - routing decisions
   - token register and unregister logic
   - websocket update handling
   - missed-alert catch-up logic
   - inbox search, filter, pagination, detail, and read-state behavior
4. New tests must verify behavior before the corresponding production refactor is considered complete.

### Real-device scenarios to design now and run later

The following scenarios will be represented in test design and manual checklists even if not executed in this pass:

1. Login registers push token.
2. Logout unregisters push token.
3. Foreground `risk_high` push opens the inbox path.
4. Foreground `risk_critical` push opens the critical-risk path.
5. Background notification tap opens the correct destination.
6. Terminated-app launch via notification uses the same routing rules.
7. Websocket notification update refreshes or surfaces the latest actionable alert.
8. Inbox item tap marks as read and opens the right detail or emergency destination.

## Verification And Evidence

This pass will use a two-tier verification model.

### Tier 1: blocking in-session verification

- backend tests
- flutter unit and widget tests
- flutter integration or harness tests that do not require device-only execution
- documented evidence of every command run

### Tier 2: deferred manual device verification

- Android manual runbook with scenario-by-scenario steps
- expected result for each scenario
- known prerequisites such as Firebase credentials, backend availability, and device connectivity

No completion claim should say "full E2E passed" unless the deferred manual device gate is actually run later.

## Known Non-Code Blockers

These are not assumed fixed by refactoring alone:

- Firebase service-account availability in the environment
- ability to trigger real push payloads on demand
- Android bridge and device state when the user runs manual verification later
- backend environment dependencies required for live alert generation

The implementation and release notes should distinguish:

- code blockers fixed in this branch
- environment blockers that still require operator action

## Refactor Scope Guardrails

In scope:

- targeted extraction of notification runtime responsibilities
- targeted extraction of notification routing normalization
- inbox test hardening
- backend test additions for proven notification contract gaps
- automation scaffolding and manual runbook for real-device checks

Out of scope:

- full rewrite of emergency flows
- broad UI redesign of the notifications screen
- speculative backend API redesign
- unrelated cleanup in neighboring modules

## Implementation Consequences

After this design is approved, the implementation plan should explicitly cover:

1. existing file ownership map
2. extraction sequence with minimal blast radius
3. TDD steps for each runtime and inbox behavior
4. backend test additions before backend patches
5. automation commands and expected evidence
6. manual device checklist artifact

## Ship Definition For This Pass

The Notifications feature is considered ship-ready for this pass when:

- automated notification gates are green
- known code blockers are fixed or documented with evidence
- real-device scenarios are fully specified for the user to run later
- there is no false claim that real-device E2E already passed

That is intentionally stronger than "looks correct" and intentionally weaker than "all device scenarios already executed".
