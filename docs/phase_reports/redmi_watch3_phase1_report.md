# Phase 1 Report — Redmi Watch 3 BLE (real scan, discovery-only)

## Summary

Phase 1 of `plans/redmi_watch_3_ble_plan_*.md` is complete with **Option A
scope** (Discovery + Identify only, no OS-level bond).

Why Option A: Redmi/Xiaomi watches require Mi Fitness to complete the
proprietary auth handshake before exchanging health data. Forcing a
generic OS bond from a third-party app would either fail at the link
layer or leave a dead pairing in Android settings without unlocking
data flow. Option A respects this vendor boundary: app scans BLE
honestly, reads standard GATT metadata (Device Information Service,
Battery Service) without bonding, and records the device against the
user account. Vital-sign sync is delegated to the simulator pipeline
until the Xiaomi protobuf path is implemented in a future phase.

End-to-end behaviour now:

- Real BLE scan replaces the mocked QR finder. Adverts filtered by
  `kDefaultRedmiNamePrefixes` (Redmi Watch / Mi Watch / Mi Band /
  Xiaomi). Mock fallback preserved under `DeviceMockConfig.useMockData`
  so emulator demos still walk through the legacy progressive-reveal.
- `BleService.peekMetadata(remoteId)` connects briefly, runs GATT
  discovery, reads DIS (firmware/manufacturer/model number) and Battery
  level when present, then disconnects. No `createBond()` call.
- `DeviceConnectProvider.confirmAndPair()` calls `peekMetadata` first,
  then POSTs `/devices/scan/pair` with the real MAC and best-available
  `model`. Failures during peek are non-fatal: the MAC still gets
  recorded so the user has a stable identifier in their account.
- UI copy realigned: confirm-card button changed from
  "Kết nối máy này (đang phát triển)" to "Ghi nhận thiết bị này", with
  a hint pointing the user to Mi Fitness for data sync. Demo banner
  rewritten to honestly describe the discovery-only scope.

Out of scope (deferred):

- `device_id` filter in `/metrics/vital-signs/latest`.
- Active-device persistence layer.
- Empty-state copy distinguishing connected/stale/offline.
- Xiaomi protobuf data sync.

## Files Modified

Created (1):

- `lib/core/services/ble_service.dart` — BleService with `ensureReady()`,
  `startScan()`, `stopScan()`, `peekMetadata()`.

Edited (7):

- `pubspec.yaml` — added `flutter_blue_plus: ^1.32.12`,
  `permission_handler: ^11.3.1`.
- `android/app/src/main/AndroidManifest.xml` — `tools` namespace +
  Android 12+ BLE permission set + legacy permissions capped to
  `maxSdkVersion=30`.
- `ios/Runner/Info.plist` — Bluetooth usage descriptions.
- `lib/features/device/providers/device_connect_provider.dart` —
  rewrite scan/select pipeline, introduce `DiscoveredDevice` value
  object, peek GATT metadata before pair, keep mock fallback.
- `lib/features/device/widgets/device_connect/device_qr_scan_step.dart`
  — replaced QR placeholder with live BLE list + typed error view.
- `lib/features/device/widgets/device_connect/method_select_step.dart`
  — updated CTA copy to BLE-first.
- `lib/features/device/widgets/device_connect/device_identity_confirm_card.dart`
  — unlocked confirm action, label "Ghi nhận thiết bị này", hint Mi
  Fitness for data sync.
- `lib/features/device/widgets/device_connect/device_connect_demo_banner.dart`
  — banner copy reflects discovery-only scope honestly.

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
