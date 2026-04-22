# Notifications Real-Device Runbook

## Status

- Deferred: this runbook is not executable end-to-end in the current local environment.
- Current blockers:
  - Firebase credentials and operator-triggered pushes are not wired for unattended local execution.
  - A compatible local integration-test target is not available on this machine today.
  - Device-side evidence capture still needs an operator-driven pass on a real Android device.

## Preconditions

- Android device connected and visible in `flutter devices`
- backend reachable from device
- Firebase push credentials configured
- a patient account that can receive `risk_high`, `risk_critical`, and `sos` notifications

## Scenarios

1. Login registers push token
2. Logout unregisters push token
3. Foreground `risk_high` push opens notifications inbox path
4. Foreground `risk_critical` push opens critical-risk presenter
5. Background tray tap opens the correct destination
6. Terminated-app notification launch follows the same routing rules
7. Websocket event updates the latest actionable notification
8. Inbox tap marks the item read and opens the correct detail or emergency screen

## Evidence Table

| Scenario | Expected result | Evidence to capture |
|----------|-----------------|---------------------|
| Login token sync | backend accepts `/notifications/push-token` | backend log + app log |
| Logout token unregister | backend accepts `/notifications/push-token/unregister` | backend log + app log |
| Foreground high risk | inbox opens, no critical takeover | screen recording |
| Foreground critical risk | critical takeover appears | screen recording |
| Tray tap | correct screen opens once | screen recording |
| Cold start | app lands on correct destination | screen recording |
| Websocket catch-up | latest alert appears once | app log + screen |
| Inbox read-state | unread count decrements | screen recording |
