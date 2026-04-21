# Emergency Release Checklist

Single pass/fail gate for:
- `Manual SOS`
- `Risk Escalation / Critical Overlay`

This checklist replaces the stale reference to `plans/risk-alert-escalation-end-to-end-plan.md`.

## 1. Scope

### Manual SOS
- `POST /mobile/emergency/sos/trigger`
- `GET /mobile/emergency/caregiver/sos-alerts`
- `GET /mobile/emergency/sos/{id}`
- `POST /mobile/emergency/sos/{id}/resolve`
- `ManualSOSScreen`
- `SosConfirmScreen`
- `EmergencySOSReceivedListScreen`
- `EmergencySOSDetailScreen`

### Risk Escalation / Critical Overlay
- `POST /mobile/risk/calculate`
- `POST /mobile/risk/alerts/{notification_id}/respond`
- realtime ingest / push / overlay / native takeover path
- `RiskAlertFullScreenOverlay`
- `SOSRealtimeAlertService`
- Android bridge in `MainActivity.kt`

## 2. Preflight

### Backend
- [ ] Backend runs locally on port `8000`
- [ ] Real DB reachable and seeded with dedicated emergency test users
- [ ] `RUN_REAL_DB_E2E=1` suites pass for manual SOS and risk response

### Android USB
- [ ] Device detected by host `adb devices`
- [ ] `adb reverse tcp:8000 tcp:8000` applied before app launch
- [ ] Notification permission granted
- [ ] Full-screen intent permission granted
- [ ] Location permission granted for manual SOS
- [ ] FCM token registration confirmed via `/notifications/push-token`

### Evidence capture
- [ ] Screen recording path prepared
- [ ] Backend log capture prepared
- [ ] DB proof capture prepared for `alerts`, `risk_alert_responses`, `sos_events`

## 3. Automated Gates

### Backend contract
- [x] `backend/tests/test_emergency_routes_http.py`
- [x] `backend/tests/test_emergency_service_contract.py`
- [ ] `backend/tests/test_risk_escalation_flow.py`

### Backend live DB
- [ ] `backend/tests/test_e2e_manual_sos.py`
- [ ] `backend/tests/test_e2e_risk_notification.py`
- [ ] `backend/tests/test_e2e_risk_response_real_db.py`

### Flutter focused
- [x] `test/features/emergency/screens/manual_sos_screen_test.dart`
- [x] `test/features/emergency/screens/emergency_sos_flow_test.dart`
- [x] `test/features/emergency/screens/sos_confirm_screen_test.dart`
- [x] `test/features/emergency/services/sos_realtime_alert_service_helpers_test.dart`
- [x] `test/features/emergency/services/sos_realtime_alert_service_flow_test.dart`
- [x] `test/features/emergency/widgets/risk_alert_full_screen_overlay_test.dart`

### Device harness / integration
- [ ] `integration_test/emergency_manual_sos_real_device_e2e_test.dart`
- [ ] `integration_test/emergency_risk_alert_real_device_e2e_test.dart`

## 3.1 Current Verification Snapshot

- Fresh verification captured on April 21, 2026 in [`progress.md`](../../progress.md).
- Host Flutter focused suite passed: `22 passed`.
- Backend Emergency contract/service suite passed: `8 passed`.
- Live DB suites are present and compile, but remain skipped until `RUN_REAL_DB_E2E=1`.
- Integration harness execution is still blocked on this machine by missing Windows desktop Visual Studio toolchain and by unavailable real-device `adb`.

## 4. Manual SOS Device Matrix

### Blocking
- [ ] Patient login works on device
- [ ] Manual SOS trigger reaches confirm screen with backend `recipient_count`
- [ ] SOS row persisted in `sos_events`
- [ ] Caregiver alert row persisted in `alerts`
- [ ] Caregiver can open SOS list after login
- [ ] Caregiver can open detail
- [ ] Caregiver can resolve SOS
- [ ] Resolved detail shows parsed `resolution_status`

### Stretch
- [ ] Second device confirms live caregiver push receipt

## 5. Risk Escalation Device Matrix

### Foreground
- [ ] Critical risk opens full-screen overlay
- [ ] `safe` response acknowledged successfully

### Background
- [ ] Notification tap or takeover opens critical overlay
- [ ] `help_requested` reaches risk-escalation confirm mode

### Terminated / native takeover
- [ ] Native bridge launch payload reopens critical flow
- [ ] Timeout escalation path completes

### Auth recovery
- [ ] Expired access token + valid refresh token still recovers response flow
- [ ] Refresh failure redirects to login
- [ ] Pending critical alert is replayed after authentication

## 6. Exact Host Commands

### Backend live DB
```powershell
$env:RUN_REAL_DB_E2E = "1"
.\venv\Scripts\python.exe -m pytest tests/test_e2e_manual_sos.py tests/test_e2e_risk_response_real_db.py tests/test_e2e_risk_notification.py -q -s
```

### Flutter focused
```bash
flutter test test/features/emergency
```

### Real device
```powershell
adb reverse tcp:8000 tcp:8000
flutter test integration_test/emergency_manual_sos_real_device_e2e_test.dart -d <device-id>
flutter test integration_test/emergency_risk_alert_real_device_e2e_test.dart -d <device-id>
```

## 7. Current Known Blockers

- Host `adb` is not available in the current WSL execution context.
- Host Windows desktop integration target is missing the Visual Studio toolchain required by `flutter test ... -d windows`.
- Host backend cannot boot the real app path because PostgreSQL on `localhost:5432` is not running.
- Real-device execution must run from a host terminal until the bridge is repaired.
- One connected device is enough for sequential patient/caregiver verification, but not enough for live two-device caregiver push proof.

## 8. Release Decision

### Pass
- All blocking items checked
- Automated gates green
- Device evidence archived

### Conditional pass
- Two-device caregiver live push missing, but backend evidence + caregiver list/detail visibility after re-login are confirmed

### Fail
- Any blocking item unchecked
- Risk auth recovery unverified
- Manual SOS resolve round-trip unverified
