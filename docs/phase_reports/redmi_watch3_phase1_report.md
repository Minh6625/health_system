# Phase 1 Report — Redmi Watch 3 BLE (real scan & pair)

## Summary

Phase 1 of `plans/redmi_watch_3_ble_plan_*.md` is complete. The Flutter
device-connect flow now drives a **real BLE scan/connect** against the
Redmi Watch 3 (M2216W1) instead of the previous hard-coded mock list,
while preserving the mock branch for emulator builds.

What changed end-to-end:

- Added `flutter_blue_plus` and `permission_handler` to `pubspec.yaml`,
  with version pins documented in-line.
- Declared the Android 12+ permission set (`BLUETOOTH_SCAN` with
  `neverForLocation`, `BLUETOOTH_CONNECT`) plus legacy `BLUETOOTH` /
  `BLUETOOTH_ADMIN` (capped at `maxSdkVersion=30`) in
  `AndroidManifest.xml`. iOS Info.plist gained
  `NSBluetoothAlwaysUsageDescription` /
  `NSBluetoothPeripheralUsageDescription`.
- Implemented `lib/core/services/ble_service.dart` exposing
  `ensureReady()`, `startScan()`, `stopScan()`. Errors surface as a typed
  `BleFailure` with discriminated `BleFailureReason` codes so the UI can
  render contextual CTAs (turn on Bluetooth, open settings, scan
  timeout, etc.).
- Rewrote `DeviceConnectProvider` so `openQrScanner()` runs a live
  `BleService` scan, deduplicates by `remoteId`, sorts by RSSI, and
  picks up the existing `/devices/scan/pair` backend endpoint with a
  real MAC address. `DeviceMockConfig.useMockData=true` keeps the
  previous progressive-reveal mock alive for emulators.
- Replaced the fake QR-finder UI in `device_qr_scan_step.dart` with a
  live BLE list and a typed error view (`_ScanErrorView`) that maps each
  `BleFailureReason` to user-actionable advice.
- Updated `method_select_step.dart` copy from "Quét QR thiết bị" to
  "Quét BLE quanh đây" so the entry CTA matches what the screen actually
  does.

The legacy `confirmAndPair()` path is intentionally preserved: it still
calls `DeviceRepository.pairNewDevice()` against `/devices/scan/pair`,
which is already wired and validated by the backend. We did not touch
the backend in this phase.

Out of scope (deferred per anh's instruction "Phase 1 only"):

- `device_id` filter in `/metrics/vital-signs/latest` and friends.
- Active-device persistence layer (`ActiveDeviceService`).
- Vital card empty-state copy distinguishing connected/stale/offline.

## Files Modified

Created (1):

- `lib/core/services/ble_service.dart`

Edited (5):

- `pubspec.yaml` — added `flutter_blue_plus: ^1.32.12`,
  `permission_handler: ^11.3.1`.
- `android/app/src/main/AndroidManifest.xml` — `tools` namespace +
  Android 12+ BLE permission set + legacy permissions capped to
  `maxSdkVersion=30`.
- `ios/Runner/Info.plist` — Bluetooth usage descriptions.
- `lib/features/device/providers/device_connect_provider.dart` —
  rewrite scan/select pipeline, introduce `DiscoveredDevice` value
  object, keep mock fallback under `DeviceMockConfig.useMockData`.
- `lib/features/device/widgets/device_connect/device_qr_scan_step.dart`
  — replaced QR placeholder with live BLE scan list + typed error view.
- `lib/features/device/widgets/device_connect/method_select_step.dart`
  — updated CTA copy to reflect BLE-first behaviour.

No files deleted.

## Verification

### Static analysis

`flutter analyze` on the four touched/created files:

```
Analyzing 4 items...
No issues found! (ran in 1.5s)
```

Full-project `flutter analyze` reports 15 pre-existing issues unrelated
to this phase (test files for Fall feature, `withOpacity` deprecations
in shared widgets). None of them touch the files modified in this
phase. Evidence in `terminals/` (run on 2026-05-20):

```
15 issues found. (ran in 123.3s)
```

All 15 are in `test/**` and `lib/shared/widgets/app_loading_screen.dart`
/ `lib/features/health_monitoring/widgets/vital_safe_range.dart`, none
of which were modified in Phase 1. Verdict: no regressions introduced.

### `flutter pub get`

Resolved cleanly with `flutter_blue_plus` and `permission_handler`
along with their transitive deps:

```
+ permission_handler 11.4.0
+ permission_handler_android 12.1.0
+ permission_handler_apple 9.4.7
...
Changed 13 dependencies!
```

### Manual testing — pending

Manual end-to-end test on a real Android device with a Redmi Watch 3
nearby is required and has **not yet been performed in this report
window** because the agent does not have access to physical hardware.
Anh sẽ chạy thử khi có máy Android + đồng hồ.

Test checklist for hand-off:

- [ ] Scan finds Redmi Watch 3 with its real advertised name (likely
      "Redmi Watch 3" or "Mi Watch") within 30 s.
- [ ] Tapping the device → confirm card → "Kết nối máy này" → backend
      DB row appears in `devices` with the real MAC.
- [ ] Toggle Bluetooth off mid-scan → error view renders the "Hãy bật
      Bluetooth" hint.
- [ ] Deny `BLUETOOTH_SCAN` permission → error view renders the
      permission CTA.
- [ ] Watch already paired with Mi Fitness → either the watch does not
      advertise (BLE invisible) or pairing fails at the platform layer;
      surface the existing "Ghép nối thất bại" copy with the underlying
      message.
- [ ] Set `DeviceMockConfig.useMockData = true` → emulator still walks
      through the mock list and shows the "MOCK" badge.

## Verdict

**PASS (code complete)** — static checks clean for the changed files,
no full-project regressions introduced, mock fallback preserved for
emulator workflows, all listed Phase 1 todos closed.

**PENDING** — physical-device verification (Redmi Watch 3 nearby) must
be done by anh before merging the phase branch.

## Next steps

- Anh chạy thử trên máy Android thật với Redmi Watch 3, tick các mục
  trong checklist ở mục Verification.
- Sau khi pass, em tiếp tục Phase 2 (active-device + per-device vitals
  filter) trên branch `feat/redmi-watch3-ble-phase2-active-device`.
