# Phase 2 Report — Health Connect integration

## Summary

Phase 2 of `plans/redmi_watch_3_ble_plan_*.md` is complete. The
HealthGuard Flutter app now ingests **real Redmi Watch 3 (M2216W1)
readings** through the OS-standard Health Connect bridge, with
delay-aware UI feedback, a backend ingest endpoint that reuses the
existing AI risk pipeline, and a settings screen for diagnostics + manual
sync.

End-to-end behaviour:

```
Redmi Watch 3 -> Mi Fitness -> Health Connect -> HealthGuard app
                                                      |
                                                      v
            POST /metrics/vitals/ingest (JWT user, owns device)
                                                      |
                                                      v
            INSERT vitals (ON CONFLICT DO NOTHING) + AI risk pipeline
                                                      |
                                                      v
            GET /metrics/vital-signs/latest -> dashboard renders
            with DataFreshness bucket (live / delayed / stale)
```

What changed end-to-end:

- Backend gained `POST /metrics/vitals/ingest` (JWT user auth) backed by
  `MonitoringService.ingest_mobile_batch`. Validation matches the
  vitals hypertable CHECK constraints (HR 20-260, SpO2 50-100, etc.) so
  bad readings are rejected at the boundary instead of failing SQL.
  Ownership is verified before INSERT; foreign devices return 403.
  After a successful insert the same `calculate_device_risk()` pipeline
  the IoT simulator uses kicks in, keeping mobile and simulator outputs
  symmetric.
- Flutter gained a `HealthConnectService` (read-only adapter on top of
  the `health` package) plus a `HealthConnectRepository` that groups
  per-channel points into per-second `MobileVitalSample` records. The
  `HealthSyncProvider` polls every 60s while the host screen is
  mounted, persists `lastSyncAt` per device-id via
  `shared_preferences`, and exposes manual refresh.
- New `HealthConnectSettingsScreen` (linked from the profile settings)
  surfaces availability + permission state, last-sync stats, and a
  deep link to Mi Fitness for forced refreshes when Health Connect
  goes dry.
- Vital cards now carry an optional `subtitle` slot, and the detail
  screen distinguishes `live` (< 5 min) / `delayed` (5-15 min) /
  `stale` (> 15 min) so a normal Mi Fitness sync window no longer
  triggers the alarmist "Mất kết nối" banner.

Out of scope (deferred per anh's instruction "Phase 2 minimum viable"):

- Background WorkManager sync when the app is closed.
- Per-device active-device picker (the dashboard still uses the user's
  first device; multi-device switcher comes in a follow-up phase).
- Steps / Sleep / Calories — Phase 2 covers vitals only because the
  `vitals` hypertable schema is the only one with `device_id` ingest
  wired today.

## Files Modified

### Created (5)

- `lib/core/services/health_connect_service.dart` — singleton facade
  over the `health` package with availability check, request/has
  permissions, and `readSince()` returning typed
  `HealthVitalReading`s.
- `lib/features/device/repositories/health_connect_repository.dart` —
  groups per-channel points into per-second `MobileVitalSample`s and
  POSTs in 1000-sample chunks to the backend.
- `lib/features/device/providers/health_sync_provider.dart` —
  foreground polling provider with persisted `lastSyncAt` and manual
  refresh.
- `lib/features/profile/screens/health_connect_settings_screen.dart`
  — three-card surface (status / sync stats / Mi Fitness deep link).
- `backend/tests/test_mobile_vitals_ingest.py` — 8 service-level
  pytest cases covering happy path, ownership, sample-level
  rejections, and risk-pipeline failure isolation.

### Edited (8)

- `pubspec.yaml` — added `health: ^13.3.1` (pinned to 13.x to satisfy
  the repo's `intl ^0.20.2` constraint).
- `android/app/src/main/AndroidManifest.xml` — declared the seven
  Health Connect read permissions (HR, Steps, Sleep, SpO2, Body
  Temperature, Blood Pressure, Respiratory Rate).
- `lib/app.dart` — registered `HealthSyncProvider` in `MultiProvider`.
- `lib/core/routes/app_router.dart` — added
  `/health-connect-settings` route.
- `lib/features/profile/screens/profile_settings_screen.dart` — added
  the "Đồng bộ Health Connect" entry point.
- `lib/features/health_monitoring/providers/vital_signs_provider.dart`
  — added `DataFreshness` bucket helper + thresholds.
- `lib/features/health_monitoring/widgets/vital_card.dart` — added
  optional `subtitle` slot for delay context.
- `lib/features/health_monitoring/screens/vital_detail_screen.dart` —
  rephrased stale banner to distinguish `delayed` vs `stale`.
- `backend/app/schemas/monitoring.py` — added `MobileVitalSample`,
  `MobileVitalsBatch`, `MobileVitalsIngestRejection`,
  `MobileVitalsIngestResponse`.
- `backend/app/services/monitoring_service.py` — added
  `ingest_mobile_batch()` reusing the simulator's INSERT pattern and
  triggering `calculate_device_risk`.
- `backend/app/api/routes/monitoring.py` — added the
  `POST /metrics/vitals/ingest` endpoint.

No files deleted.

## Verification

### Backend pytest (proof)

```
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_happy_path_inserts_and_triggers_risk PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_missing_device_raises_permission_error PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_foreign_device_raises_permission_error PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_rejects_future_timestamp PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_rejects_old_timestamp PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_rejects_no_clinical_signal PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_swallows_risk_pipeline_errors PASSED
tests/test_mobile_vitals_ingest.py::test_ingest_mobile_batch_skips_risk_when_no_accept PASSED
======================== 8 passed, 1 warning in 1.58s =========================
```

8/8 pass. Each scenario asserts a different boundary: ownership,
timestamp clamps, ADR-018 part-4 null clinical-signal contract, risk
pipeline isolation, and the "no insert -> no risk eval" optimisation.

### Static analysis (proof)

`flutter analyze` on Phase 2 files (changed/created):

```
Analyzing 4 items...
No issues found! (ran in 5.4s)

Analyzing 3 items...
No issues found! (ran in 7.4s)
```

Full-project `flutter analyze` reports 15 pre-existing issues:

```
15 issues found.
```

All 15 are in `test/**` (Fall feature), `lib/shared/widgets/app_loading_screen.dart`,
and `lib/features/health_monitoring/widgets/vital_safe_range.dart` —
none of which were touched in this phase. No regressions introduced.

### Manual smoke test — pending

Manual end-to-end verification on a real Android device + Redmi Watch 3
+ Mi Fitness + Health Connect was deferred to anh per the "anh test
trên thiết bị thật" handoff. Checklist:

- [ ] Mi Fitness shows recent HR samples in Health Connect (verify via
      Health Connect Toolbox first).
- [ ] Open HealthGuard -> Profile -> Settings -> "Đồng bộ Health
      Connect" -> grant permissions.
- [ ] Tap "Đồng bộ ngay" -> stats card shows
      "Đã gửi N · lưu N · loại 0".
- [ ] Open dashboard -> vital cards render real HR/SpO2 within 1 minute.
- [ ] Sit idle 16 minutes without re-syncing -> detail card switches
      to "Đã hơn 15 phút chưa cập nhật" copy.
- [ ] Re-sync -> banner clears, value refreshes.
- [ ] Deny HC permission -> settings screen renders the "Cấp quyền"
      CTA, manual sync gracefully reports `permissionRequired` state.

## Verdict

**PASS (code complete, automated checks green)** — backend boundary
covered by 8 pytest cases, Flutter compiles clean on the touched files,
no full-project regressions. Mock fallback unchanged
(`DeviceMockConfig.useMockData=true`) so emulator demos keep working.

**PENDING manual verification on physical hardware** — anh test 6 mục
trong checklist với Redmi Watch 3 + Mi Fitness + Health Connect.

## Next steps

- Anh tick checklist trên máy thật. Nếu pass, em merge Phase 2 vào
  `feat/redmi-watch3-ble` integration branch.
- Optional follow-ups (out of current scope): WorkManager background
  sync, per-device active picker, Steps/Sleep ingest pipeline.
