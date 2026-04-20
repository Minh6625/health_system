# Findings: Sleep Analysis Ship Review

## Requirements
- Deeply analyze the current `Sleep Analysis` module.
- Determine what still must be fixed or refactored to ship full E2E.
- Build a thorough test plan: Flutter flow, backend integration/E2E, and real-device validation.
- Focus on user-facing flows:
  - ingest sleep session -> DB -> latest report -> history -> detail
  - self profile
  - linked profile via `X-Target-Profile-Id`
  - settings/local UX not breaking the core flow
  - no-data / before-6AM rule / canonical `sleep_date`

## Research Findings
- Context layer is ready: MemPalace available and semantic health resource reports `ok`.
- `health_system` is the active repo and is GitNexus-indexed.
- Current repo contains the sleep screens/provider/repository and the backend/tests named by the user.
- The referenced `plans/sleep/README.md` file is not present in the current repo snapshot, while `plans/E2E/full-e2e-matrix.md` still cites it as the source plan. Sleep release documentation is stale.
- Canonical mobile sleep contract today is:
  - ingest: `/mobile/telemetry/sleep`
  - latest: `/mobile/metrics/sleep/latest`
  - history: `/mobile/metrics/sleep/history`
- Backend canonical semantics are consistent at the contract level:
  - `ingest_sleep_session()` persists `sleep_date` directly from payload and upserts on `(user_id, device_id, sleep_date)`
  - monitoring latest/history read `sleep_sessions` ordered by `sleep_date DESC`
  - builder normalizes `sleep_date` and falls back to `end_time.date()` when absent
- Existing automated evidence is strong but split across layers:
  - backend contract + route tests passed again: `14 passed`
  - Flutter sleep repository/provider/widget/screen tests passed again: `16 passed`
  - live DB E2E gate does not currently pass cleanly: `1 failed, 2 passed, 1 error`
  - `integration_test/` contains only `home_dashboard_real_device_e2e_test.dart`; there is no dedicated real-device sleep suite
- The only current real-device proof for sleep is a brief drilldown from risk detail that checks the title `Báo cáo Giấc ngủ`; it does not verify sleep latest/history/detail/settings/no-data/linked-profile behavior end-to-end.
- `SleepHistoryScreen` does not navigate to detail; tapping a chart bar or list item only updates provider state and pops back to the report screen. This does not satisfy the release flow `latest report -> history -> detail`.
- Home dashboard preview and sleep screens do not share the exact selected `sleep_date`:
  - dashboard preview fetches `/metrics/sleep/latest`
  - tapping the sleep card routes only `{profileId}` to `/sleep-report`
  - `SleepReportScreen` fetches latest again on bootstrap instead of carrying the preview date/session
  This leaves a semantics gap between preview and the opened report when new data arrives or state changes between screens.
- `SleepProvider.selectDate()` collapses all repository failures into `SleepLoadState.error` without setting a new `errorMessage`, and `SleepReportScreen` responds by replacing the whole body with `_ErrorView`. A date-specific fetch failure can therefore hide already-loaded data behind a generic error state.
- `SleepSettingsScreen` is purely local state; it is safe as optional UX, but it is not persisted and should not be counted as a verified settings feature beyond local interaction.
- `SleepRepositoryImpl.getSleepHistory()` still accepts multiple wrapper shapes (`data`, `items`, `sessions`) instead of failing on the canonical backend shape. That makes contract regressions easier to miss in production.
- The live DB E2E gate has two release-significant failures unrelated to Flutter mocks:
  - the caregiver fixture inserts `role='caregiver'`, which violates the current database `users_role_check`
  - the vitals ingest test now returns `errors=["risk_eval_failed ... RiskScore"]` instead of a clean empty error list
  Sleep read-path tests still pass inside that suite, but the release gate described in planning docs is not green.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Analyze code in four slices: backend ingest/read, mobile flow, existing tests, ship blockers | Keeps the review grounded in user-facing behavior instead of isolated files |
| Treat provider/widget tests and backend contract tests as necessary but insufficient evidence | User asked for true E2E readiness, which requires real-device proof |
| Treat `monitoring.py` + `telemetry.py` as the canonical sleep contract | These are the route layers the Flutter app and live DB E2E test actually call today |
| Treat working-tree code and fresh test output as source of truth over stale planning docs | The current repo snapshot does not contain the sleep plan file cited by the E2E matrix |

## Resources
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\repositories\sleep_repository.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\models\sleep_session.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\providers\sleep_provider.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\screens\sleep_report_screen.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\screens\sleep_detail_screen.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\screens\sleep_history_screen.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\sleep_analysis\screens\sleep_settings_screen.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\home\presentation\screens\home_dashboard_screen.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\features\home\repositories\home_dashboard_repository.dart`
- `D:\DoAn2\VSmartwatch\health_system\lib\core\routes\app_router.dart`
- `D:\DoAn2\VSmartwatch\health_system\backend\app\api\routes\telemetry.py`
- `D:\DoAn2\VSmartwatch\health_system\backend\app\api\routes\monitoring.py`
- `D:\DoAn2\VSmartwatch\health_system\backend\app\services\monitoring_service.py`
- `D:\DoAn2\VSmartwatch\health_system\backend\app\core\dependencies.py`
- `D:\DoAn2\VSmartwatch\health_system\backend\tests\test_monitoring_service_contract.py`
- `D:\DoAn2\VSmartwatch\health_system\backend\tests\test_monitoring_routes_http.py`
- `D:\DoAn2\VSmartwatch\health_system\backend\tests\test_e2e_telemetry_real_db.py`
- `D:\DoAn2\VSmartwatch\health_system\test\features\sleep_analysis\repositories\sleep_repository_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\test\features\sleep_analysis\providers\sleep_provider_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\test\features\sleep_analysis\widgets\sleep_widgets_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\test\features\sleep_analysis\screens\sleep_flow_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\test\features\home\presentation\screens\home_dashboard_navigation_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\test\features\home\presentation\screens\home_dashboard_screen_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\integration_test\home_dashboard_real_device_e2e_test.dart`
- `D:\DoAn2\VSmartwatch\health_system\plans\E2E\full-e2e-matrix.md`
