# Risk Contract Baseline

> Source of truth for the **mobile-facing risk DTOs** produced by the backend
> and consumed by the Flutter app. Always reflects the contract at the
> baseline version listed below. Each Phase update bumps the version and
> appends an entry to the [Version history](#version-history) table.

| Field | Value |
| --- | --- |
| Baseline version | `v1.5.1` (Phase 8 slice 4a — mobile clinician audience toggle) |
| Wire version | `0.5.0` (unchanged — toggle just sends an existing optional query param) |
| Captured from branch | `feat/risk-core-phase8-clinician-toggle` |
| Pending DBA migrations | `backend/migrations/20260427_model_request_id.sql`, `backend/migrations/20260427_sleep_risk_type.sql`, `backend/migrations/20260427_audience_payload_json.sql` |
| Audience helper | `backend/app/core/audience.py` |
| Audience cache helpers | `MonitoringService._read_audience_cache` / `_write_audience_cache` |
| Clinician schema | `backend/app/schemas/monitoring.py::RiskReportClinicianResponse` |
| Clinician toggle (mobile) | `lib/features/profile/providers/clinician_audience_provider.dart` + `screens/profile_settings_screen.dart` |
| Fall quality harness | `backend/tests/eval/test_fall_classifier_quality.py` (gated by `RUN_EVAL=1`) |
| Fall events read service | `backend/app/services/fall_event_service.py` |
| Fall events routes | `backend/app/api/routes/fall_events.py` (`GET /mobile/fall-events`, `GET /{id}`, `POST /{id}/dismiss`) |
| Fall critical push | `PushNotificationService.send_fall_critical_alert` |
| Fall push handler (mobile) | `lib/core/notifications/fall_event_handler.dart` |
| Fall persistence adapter | `backend/app/adapters/fall_persistence_adapter.py` |
| Sleep risk adapter | `backend/app/adapters/sleep_risk_adapter.py` |
| IMU window route | `POST /mobile/telemetry/imu-window` (`backend/app/api/routes/telemetry.py`) |
| Sleep risk route | `POST /mobile/telemetry/sleep-risk` (`backend/app/api/routes/telemetry.py`) |
| IMU window schemas | `backend/app/schemas/fall_telemetry.py` |
| Sleep risk schemas | `backend/app/schemas/sleep_telemetry.py` |
| Schema source | `backend/app/schemas/monitoring.py` |
| Version constant | `backend/app/core/risk_contract.py` |
| Circuit breaker | `backend/app/services/circuit_breaker.py` |
| Timing observability | `backend/app/observability/timing.py` |
| Mobile version inspector | `lib/core/network/risk_contract_version.dart` |
| Normalized row (read path) | `backend/app/services/normalized_risk_row.py` |
| Normalized explanation (write path) | `backend/app/adapters/normalized_explanation.py` |
| Model-api adapter | `backend/app/adapters/model_api_health_adapter.py` |
| Persistence adapter | `backend/app/adapters/risk_persistence_adapter.py` |
| Mobile DTO builder | `backend/app/services/risk_report_builder.py` |
| DTO snapshot test | `backend/tests/contract/test_mobile_risk_dto_snapshot.py` |
| Versioning + OpenAPI test | `backend/tests/contract/test_mobile_risk_versioning.py` |
| Breaker unit test | `backend/tests/test_circuit_breaker.py` |
| Timing unit test | `backend/tests/test_observability_timing.py` |
| Breaker integration test | `backend/tests/test_model_api_client_breaker.py` |
| Builder unit test | `backend/tests/test_risk_report_builder.py` |
| Persistence adapter test | `backend/tests/test_risk_persistence_adapter.py` |
| Mobile parser | `lib/features/analysis/repositories/risk_analysis_repository.dart` |
| Mobile inspector test | `test/core/network/risk_contract_version_test.dart` |
| Risk plan | `.windsurf/plans/risk-core-architecture-refactor-9ea607.md` |

> **Plan-vs-execution note**: the plan's *Phase 2* is a persistence-schema
> migration (alembic, new columns) and *Phase 3* is the
> `risk_alert_service` adapter extraction. The intermediate builder +
> typed-row work landed under the `v0.1 → v0.3` versions is **preparatory
> infrastructure for the plan's Phase 3** (the `MobileRiskDtoAdapter`
> portion plus its input type), not the full Phase 3. Plan's Phase 2
> (alembic) is intentionally deferred — it requires DBA + production
> migration window per the plan's risk note.

## Version history

| Version | Date | Branch | Change |
| --- | --- | --- | --- |
| `v0.0` | 2026-04-27 | `refactor/risk-core-phase0-audit` | Plan's Phase 0: initial baseline pinned by snapshot tests. |
| `v0.1` | 2026-04-27 | `refactor/risk-core-phase1-canonicalize` | Plan's Phase 1: marked duplicate fields `deprecated=True` (no wire-format change), added invariance tests, flipped mobile parser to prefer canonical keys. |
| `v0.2` | 2026-04-27 | `refactor/risk-core-phase2-builder-extract` | **Out-of-plan refactor** (mislabelled as "Phase 2" in the original commit; the plan's Phase 2 is a persistence migration). Extracted `build_risk_report` / `build_risk_report_detail` / `build_risk_history_item` into `app/services/risk_report_builder.py`. Logically belongs in plan's Phase 3 (as the `MobileRiskDtoAdapter`). |
| `v0.3` | 2026-04-27 | `refactor/risk-core-phase3-typed-normalized-row` | **Phase 3a — prep**: replaced the `dict[str, Any]` returned by `MonitoringService._normalize_risk_row` with a frozen `NormalizedRiskRow` dataclass. All 7 internal call sites + builders + builder tests migrated. No wire-format change. Sets up the typed input layer the plan's Phase 3 adapter extraction will produce. |
| `v0.4` | 2026-04-27 | `refactor/risk-core-phase3b-adapters` | **Plan's Phase 3 — adapter formalisation**: extracted `ModelApiHealthAdapter` (`to_record` / `from_response` / `from_local_inference` + 7 private helpers) and `RiskPersistenceAdapter` (`build_features_json` / `persist`) under `backend/app/adapters/`. `risk_alert_service.calculate_device_risk` shrank from 263 LOC to 99 LOC; the file as a whole went from 773 to 393 LOC. Verbatim behaviour: medical defaults (75 bpm / 120-80 / 165 cm / 65 kg / 50 ms HRV), recommendations copy, explanation text format, and `feature_importance` rounding are all unchanged. |
| `v0.5` | 2026-04-27 | `refactor/risk-core-phase6-versioning` | **Plan's Phase 6 — versioning + OpenAPI guard**: added `RISK_CONTRACT_VERSION = "0.4.0"` constant + `RiskContractVersionMiddleware` so every response on the mobile risk surface (`/mobile/analysis/risk-reports`, `/risk-reports/{id}`, `/risk-history`, `/mobile/metrics/health-report`) carries `X-Risk-Contract-Version`. Mobile `ApiClient` reads + debug-warns once per distinct mismatch via the new `RiskContractVersion` singleton. New `tests/contract/test_mobile_risk_versioning.py` (23 tests) pins the route surface, the header presence, the header scope (off-surface routes do NOT get the header) and the OpenAPI components shape. No wire-format change. |
| `v0.6` | 2026-04-27 | `refactor/risk-core-phase7-resilience` | **Plan's Phase 7 (reduced) — resilience + observability**: added a 3-state `CircuitBreaker` (CLOSED → OPEN → HALF_OPEN) and wired it into `ModelApiClient.predict_health_risk` + `predict_fall` with **separate per-endpoint breakers** so health and fall outages cannot mask one another. Network / timeout / 5xx errors trip the breaker after `MODEL_API_BREAKER_FAILURES` (default 5) consecutive failures; malformed-JSON does NOT trip (it's a contract bug, not an outage). Added `app/observability/timing.py` with `StageTimer` context manager + `record_timing` log emitter for the four canonical stages (`build_record`, `model_api_call`, `persist`, `build_dto`). Stage timings now flow on every `calculate_device_risk` call. 26 new tests (12 breaker state-machine, 7 timing helpers, 7 breaker-on-client integration). The plan's cache (`audience_payload_json`) is **deferred** — depends on Phase 2 (alembic) and Phase 5 (audience profiles), neither landed. No wire-format change. |
| `v0.7` | 2026-04-27 | `refactor/risk-core-phase2-model-request-id` | **Plan's Phase 2 (focused subset) — `model_request_id` traceability**: added `backend/migrations/20260427_model_request_id.sql` (raw SQL — project does not use alembic) to add a nullable `VARCHAR(36)` column on `risk_explanations` with a partial index on `IS NOT NULL` rows. `ModelApiHealthAdapter.from_response` extracts `meta.request_id` (defensive: `str()`-coerces, trims whitespace, truncates to 36 chars, normalises blanks to `NULL`). `NormalizedExplanation` carries the field; `RiskPersistenceAdapter.persist` writes it. Rule-based / ONNX / LightGBM fallback rows keep `NULL` (no upstream request to correlate with). Backfill is intentionally NOT done — historical rows have no recoverable request_id. **Migration is pending DBA application; the column write is forward-compatible until then.** Plan's `audience_payload_json` column deliberately deferred — purely Phase 5 prep, no consumer yet. 9 new tests. No wire-format change. |
| `v0.8` | 2026-04-27 | `refactor/risk-core-phase4b-thin-imu-window` | **Plan's Phase 4B (focused subset) — backend IMU window ingest**: added `POST /mobile/telemetry/imu-window` accepting an `ImuWindowRequest` (verbatim port of model-api `FallPredictionRequest` + `db_device_id`). The route forwards to `ModelApiClient.predict_fall` (already breaker-wrapped + timed by Phase 7), persists a `fall_events` row via the new `FallPersistenceAdapter`, and returns the `fall_event_id` + `model_request_id` for log correlation. **On `predict_fall` returning `None`** (breaker open / transport / 5xx / malformed body), no row is written and the response carries `status="model_unavailable"` — false-negatives on real falls are dangerous, so the route surfaces uncertainty rather than guessing. Confusion-matrix harness, simulator-side IMU window dispatch, mobile fall alert UI, and rule-based fall fallback all **deliberately deferred** to Phase 4B-full (needs UP-Fall + PAMAP2 datasets + push channel + mobile UI work). 23 new tests (11 adapter unit, 5 HTTP route, 7 helper). No wire-format change to existing risk DTOs. |
| `v0.9` | 2026-04-27 | `refactor/risk-core-phase4a-thin-sleep-risk` | **Plan's Phase 4A (focused subset) — backend sleep risk ingest**: added `POST /mobile/telemetry/sleep-risk` accepting a `SleepRiskRequest` (verbatim port of model-api `SleepRecord` + `db_device_id` + `db_user_id`). New `ModelApiClient.predict_sleep` with its own `model_api_sleep` breaker (independent of health + fall), forwarding to `/api/v1/sleep/predict`. New `SleepRiskAdapter` projects results into `NormalizedExplanation` with **score inversion** — model-api sleep_score 0–100 (high=good) becomes `risk_score = 100 - sleep_score` (high=worse) so sleep rows share the same axis as vitals risk rows. Persisted via existing `RiskPersistenceAdapter` with `risk_type='sleep'` (allowed by new SQL migration `20260427_sleep_risk_type.sql` relaxing the `check_risk_type` CHECK constraint). `model_unavailable` semantics mirror the IMU window route — no row written when `predict_sleep` returns `None`. Simulator-side dispatch (the dead `SleepAIClient` path), the 40-field mobile mapper, and mobile sleep risk surface all **deliberately deferred** to Phase 4A-full. 36 new tests (31 adapter + 5 route). No wire-format change to existing risk DTOs. |
| `v1.0` | 2026-04-27 | `refactor/risk-core-phase5-audience-profiles` | **Plan's Phase 5 — audience profiles + clinician role gate**: added `AudienceEnum` + `require_clinician_audience` in `app/core/audience.py`. Audit revealed `users.role` already exists (no RBAC migration needed) — `CLINICIAN_ROLES = {"clinician", "admin"}`. New `RiskReportClinicianResponse` extends the existing `RiskReportDetailResponse` with two clinical-only fields: `shap_details` (raw SHAP waterfall) + `model_request_id` (Phase 2 traceability surfaced on the read path). The detail route's `response_model` is now `RiskReportDetailResponse \| RiskReportClinicianResponse` (FastAPI emits an `anyOf` in OpenAPI). `audience=patient` is the default, so existing Flutter binaries are unaffected. `audience=clinician` from a non-clinician role returns HTTP 403. Read-path SQL extended to include `shap_details_json` + `model_request_id` from `risk_explanations`; `NormalizedRiskRow` carries both. Wire version bumped `0.4.0 -> 0.5.0` (minor — additive optional fields). 8 new tests (7 audience-gating + 1 anyOf-OpenAPI). No mobile wire-format change for patient surface. |
| `v1.1` | 2026-04-27 | `refactor/risk-core-phase7-audience-cache` | **Plan's Phase 7 — audience-payload DTO cache**: added `risk_explanations.audience_payload_json` JSONB column (`backend/migrations/20260427_audience_payload_json.sql`) + nullable column on the ORM. Read-path detail handlers (`MonitoringService.get_risk_report_detail` / `get_risk_report_clinician_detail`) now follow a **lazy write-through cache** pattern: cache-first lookup keyed by `(audience, RISK_CONTRACT_VERSION)`; on miss, build via the existing assembly path then UPDATE the row. Cache writes are **best-effort** (failures are logged + rolled back but the request still returns the freshly-built DTO). Cache invalidation is automatic on contract-version bump (the version is the cache key suffix) so a future Phase doesn't need a manual flush job. New observability: `record_timing("build_dto", ..., cache="hit"\|"miss", reason=...)` so cache hit-rate can be charted. **No wire-format change** — cache is server-internal; the assembled DTOs are byte-for-byte identical to v1.0. 6 new tests (cache miss build, cache hit short-circuit, version invalidation, partial dict append, write-failure tolerance, timing tags). |
| `v1.2` | 2026-04-27 | `refactor/risk-core-phase4b-confusion-matrix` | **Plan's Phase 4B-full slice 2a — fall classifier confusion-matrix harness**: added `backend/tests/eval/` package with three modules: `etl_up_fall.py` (deterministic UP-Fall raw CSV → labelled JSONL), `test_etl_up_fall.py` (21 always-on unit tests pinning peak detection / window extraction / pre-pad-with-first-sample / orientation derivation / CSV parsing / committed-fixture sanity), and `test_fall_classifier_quality.py` (gated harness POSTing each labelled window to `/api/v1/fall/predict` and computing TP/TN/FP/FN → sensitivity / specificity / F1 → dated JSON report under `reports/`). Acceptance gates from plan §4B.3 §I: **sensitivity ≥ 0.90, specificity ≥ 0.85, F1 ≥ 0.87**. Audit found UP-Fall trials are 40 samples (model-api requires 50) so the ETL pre-pads with the first sample to simulate pre-event stillness — same shape a production sliding window catches. **PAMAP2 not used** because the dataset directory is empty in the simulator repo; UP-Fall already provides both classes (A01–A05 falls + A06–A11 ADLs). Wire version unchanged. Fixture: 126 windows (57 falls + 69 ADLs), checked into git. 24 new always-on tests + 3 confusion-matrix maths tests + 1 properly gated live-harness test. |
| `v1.3` | 2026-04-27 | `refactor/risk-core-phase4b-mobile-fall-events` | **Plan's Phase 4B-full slice 2c (backend half) — mobile fall-events read surface**: added three routes the Flutter `lib/features/fall/` module consumes: `GET /mobile/fall-events` (paginated list, newest-first, ``limit≤100``), `GET /mobile/fall-events/{id}` (one event), `POST /mobile/fall-events/{id}/dismiss` (mark as user-cancelled). Owner-scoped through ``X-Target-Profile-Id`` + JOIN ``devices.user_id``; non-owned ids return **HTTP 404, not 403** (no enumeration leak). New `FallEventService` projects raw rows to ``FallEventResponse`` and derives a single ``status`` string (``detected`` → ``dismissed`` / ``confirmed`` / ``escalated``) so Flutter doesn't reproduce the state machine. Dismiss is idempotent and locks the row with ``SELECT FOR UPDATE`` to prevent concurrent-tap races. New schemas (`FallEventResponse`, `FallEventListResponse`, `FallEventDismissRequest`, `FallEventDismissResponse`) added to `app/schemas/fall_telemetry.py`. Wire-version unchanged — routes outside the risk-DTO surface so the contract version doesn't apply. 23 new tests (11 service + 12 HTTP). |
| `v1.3.1` | 2026-04-27 | `feat/risk-core-phase4b-mobile-fall-feature` | **Plan's Phase 4B-full slice 2c (mobile half) — fall feature module**: added `lib/features/fall/` with model (``FallEvent`` + ``FallEventStatus`` forward-compat enum + ``FallEventList``), repository (3 methods wrapping the backend routes; 404 → null), provider (ChangeNotifier with list-state machine + dismiss in-flight guard + ``latestActiveEvent`` getter), widgets (``FallStatusChip`` + ``FallCountdownRing`` with test-overridable tick), screens (``FallAlertScreen`` full-screen overlay with PopScope-blocked back + 30 s countdown + dismiss/confirm + disclaimer; ``FallHistoryScreen`` newest-first list with empty/error/loading states + footer disclaimer). 20 new Flutter tests. No backend change in this commit — the mobile module consumes v1.3 verbatim. |
| `v1.5.1` | 2026-04-27 | `feat/risk-core-phase8-clinician-toggle` | **Plan's Phase 8 slice 4a — mobile clinician audience toggle (mobile-only, no backend change)**: added `lib/features/profile/providers/clinician_audience_provider.dart` (ChangeNotifier persisted via the existing `FlutterSecureStorage`; ``init`` is soft-fail-closed so a busted storage layer leaves the user in patient mode rather than blowing up the app). Added `lib/features/profile/screens/profile_settings_screen.dart` with a `SwitchListTile.adaptive` for "Chế độ chuyên môn"; the screen renders the toggle ONLY for users whose `currentUser.role` is in `{"clinician", "admin"}` (`isClinicianRole` is case + whitespace tolerant, mirrors the backend's `CLINICIAN_ROLES` allow-list), patient-mode users see a neutral "Chưa có cài đặt nâng cao" placeholder. Extended `RiskAnalysisRepository.fetchReportDetail` + `RiskReportProvider.fetchReportDetail` with optional `audience:` kwarg; `risk_report_detail_screen.dart` reads `ClinicianAudienceProvider.audienceQueryValue` (`null` or `"clinician"`) and forwards. `_resolveAudience` defensively catches `ProviderNotFoundException` so existing widget tests don't need to inject the new provider — production always has it via `app.dart`. New route `profileSettings = '/profile/settings'`. 21 new Flutter tests (11 provider state-machine + persistence including soft-fail-closed init, write-failure tolerance, idempotency; 10 widget tests covering role gating, switch state, init-disabled visual). Backend untouched, wire version unchanged. |
| `v1.5` | 2026-04-27 | `feat/risk-core-phase4a-mobile-sleep-filter` | **Plan's Phase 4A-full slice 3a + 3b — sleep dispatch primitive + mobile risk-type filter**: slice 3a (committed in the simulator repo at `feat/sleep-risk-dispatch` 013b400) added `pre_model_trigger/sleep_dispatch.py` with `SleepRiskDispatcher` + `filter_to_sleep_record` that strip simulator extras (`scenario_id`, `wake_count`) and submit the canonical 43-field SleepRecord via `MobileTelemetryClient.submit_sleep_record`. Slice 3b (this commit, health_system repo) adds the optional ``risk_type`` query parameter to `GET /mobile/analysis/risk-history` allow-listed against `general` / `sleep` / `fall`; case-insensitive + whitespace-tolerant; unknown values silently fall back to "no filter" so the route stays forward-compatible. Mobile-side: `RiskAnalysisRepository.fetchHistory` accepts an optional `riskType:` kwarg that's only sent on the wire when non-empty; `RiskHistoryProvider` exposes `currentRiskType` + `changeRiskType(profileId, value)` with a sentinel-based default so `null` means "clear" rather than "keep"; new `RiskTypeFilterChips` widget renders "Tất cả" / "Sức khoẻ" / "Giấc ngủ" / "Té ngã" via Material 3 ChoiceChips with active-chip-deselect swallowed (the screen always has SOMETHING selected). 13 backend filter tests + 15 Flutter tests (chip widget + provider) + 15 simulator dispatch tests, all green. **Wire version unchanged** — the param is optional + forward-compatible. |
| `v1.4` | 2026-04-27 | `feat/risk-core-phase4b-fall-push` | **Plan's Phase 4B-full slice 2d — fall critical push**: added `PushNotificationService.send_fall_critical_alert` — dedicated fan-out for fall-detected pushes that builds a ``type='fall_alert'`` data envelope with ``fall_event_id`` + ``fall_event_uuid`` + 3-decimal ``confidence`` so the mobile handler can deep-link into ``FallAlertScreen`` without the heavy SOS state machine. Always uses the takeover path (data-only, ``notification=None``) since false negatives on a real fall are dangerous. Plus mobile `lib/core/notifications/fall_event_handler.dart` with ``parseFallEventFromPushData`` (forward-compat parser — unknown ``type`` → null, missing/unparseable ``fall_event_id`` → null, confidence clamped to ``[0, 1]``), ``presentFallAlert`` (Navigator push with idempotent guard against duplicate retries), ``hydrateFallEvent`` (best-effort fetch of full server-side state — transport failure leaves the synthetic stub in place rather than crashing). **Wiring deferred**: calling ``send_fall_critical_alert`` from the IMU window route + hooking the handler into ``notification_runtime_service.dart`` are both touch-many-files changes that merit their own slice. 7 backend tests + 8 Flutter tests. No wire-version change — the FCM data envelope is not a risk-DTO contract surface. |

The contract is enforced by frozen `EXPECTED_*_KEYS` sets in the snapshot test.
Any unintentional shape change will fail those tests with a precise diff
("Added keys / Removed keys"), so this document and the test file must be
updated together when the contract genuinely evolves.

---

## 1. Endpoints in scope

Routes are mounted under the global `/mobile` prefix
(`backend/app/api/router.py`) and the `/analysis` sub-router
(`backend/app/api/routes/monitoring.py`).

| Method | Path | Response model | Service entry |
| --- | --- | --- | --- |
| `GET` | `/mobile/analysis/risk-reports` | `list[RiskReportResponse]` | `MonitoringService.get_risk_reports` |
| `GET` | `/mobile/analysis/risk-reports/{report_id}` | `RiskReportDetailResponse` | `MonitoringService.get_risk_report_detail` |
| `GET` | `/mobile/analysis/risk-history` | `RiskHistoryResponse` | `MonitoringService.get_risk_history` |

Out-of-scope for Phase 0 (will be revisited later):

- `GET /mobile/health/report` (`HealthReportResponse`) — captured for context
  only, not pinned by the snapshot test yet.
- `POST /mobile/telemetry/...` ingestion paths — covered by separate
  e2e tests (`test_e2e_telemetry_real_db.py`).

---

## 2. `RiskReportResponse` — list item

Returned as elements of `GET /mobile/analysis/risk-reports`.

```json
{
  "id": 42,
  "risk_type": "general",
  "risk_score": 58.0,
  "score": 58.0,
  "health_score": 42.0,
  "risk_level": "medium",
  "health_level": "watch",
  "display_status": "Cần theo dõi",
  "summary": "Sức khỏe ổn định nhưng cần theo dõi nhịp tim và SpO2.",
  "timestamp": "2026-04-27T08:00:00Z",
  "previous_score": 55.0,
  "trend_7d": [55, 56, 57, 58, 59, 58, 58],
  "key_features": ["heart_rate", "spo2"],
  "top_factors": [
    {
      "key": "heart_rate",
      "label": "Nhịp tim",
      "impact": 0.42,
      "direction": "risk_up",
      "reason": "Nhịp tim cao hơn bình thường",
      "feature_value": "112 bpm"
    }
  ],
  "recommendation_preview": ["Đo lại chỉ số sau 15 phút"],
  "confidence": 0.82,
  "is_stale": false
}
```

| Key | Type | Notes |
| --- | --- | --- |
| `id` | `int` | Primary key of `risk_scores` row. |
| `risk_type` | `string` | Currently always `"general"` for the rolled-up score. Sleep/fall use the same DTO with their own type strings. |
| `risk_score` | `float` | **Deprecated alias of `score`** since `v0.1`. Removal scheduled for Phase 6. |
| `score` | `float` | **Canonical** risk value (0..100). |
| `health_score` | `float` | `100 - score`. UI surfaces this as the "good news" framing. |
| `risk_level` | `string` | `low` \| `medium` \| `high` \| `critical`. |
| `health_level` | `string \| null` | **Deprecated** since `v0.1` — overlaps with `display_status`. Removal scheduled for Phase 6. |
| `display_status` | `string` | **Canonical** localized label rendered on the dashboard chip. |
| `summary` | `string` | One-line Vietnamese narrative. |
| `timestamp` | `datetime` | ISO-8601 UTC. |
| `previous_score` | `float \| null` | Score of the immediately prior report. |
| `trend_7d` | `int[]` | Up to 7 daily samples used by the dashboard sparkline. |
| `key_features` | `string[]` | **Deprecated** since `v0.1` — derivable from `top_factors[].key`. Removal scheduled for Phase 6. |
| `top_factors` | `TopFactorResponse[]` | See section 5. |
| `recommendation_preview` | `string[]` | First 2 recommendations, used in list rows. |
| `confidence` | `float` | Model confidence (0..1). |
| `is_stale` | `bool` | `true` when the latest score is older than the freshness window. |

---

## 3. `RiskReportDetailResponse` — detail screen

Returned by `GET /mobile/analysis/risk-reports/{report_id}`.

```json
{
  "id": 42,
  "risk_type": "general",
  "risk_score": 58.0,
  "score": 58.0,
  "health_score": 42.0,
  "risk_level": "medium",
  "health_level": "watch",
  "display_status": "Cần theo dõi",
  "summary": "Sức khỏe ổn định nhưng cần theo dõi nhịp tim và SpO2.",
  "timestamp": "2026-04-27T08:00:00Z",
  "previous_score": 55.0,
  "trend_7d": [55, 56, 57, 58, 59, 58, 58],
  "explanation": "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
  "xai_explanation": "Nhịp tim cao và SpO2 thấp đang đẩy mức rủi ro lên.",
  "features": { "heart_rate": 112, "spo2": 94 },
  "feature_importance": { "heart_rate": 0.42, "spo2": 0.31 },
  "breakdown": [
    {
      "key": "spo2",
      "label": "SpO₂",
      "contribution_score": 0.31,
      "impact_level": "medium",
      "value": "94",
      "unit": "%",
      "route_target": "vitals/spo2",
      "direction": "risk_up",
      "reason": "SpO2 dưới 95% kéo dài"
    }
  ],
  "recommendations": [
    "Đo lại chỉ số sau 15 phút",
    "Nghỉ ngơi tại chỗ"
  ],
  "recommendation_preview": ["Đo lại chỉ số sau 15 phút"],
  "top_factors": [
    {
      "key": "heart_rate",
      "label": "Nhịp tim",
      "impact": 0.42,
      "direction": "risk_up",
      "reason": "Nhịp tim cao hơn bình thường",
      "feature_value": "112 bpm"
    }
  ],
  "snapshot": {
    "heart_rate": 112,
    "spo2": 94,
    "sys_bp": 128,
    "dia_bp": 82,
    "body_temp": 36.9,
    "hrv": 42,
    "map_val": 97
  },
  "model_version": "model_api_v1",
  "algorithm": "model_api_health",
  "confidence": 0.82,
  "is_stale": false,
  "ai_explanation": {
    "short_text": "Nhịp tim và SpO2 cần theo dõi sát.",
    "clinical_note": "HR 112 bpm vượt ngưỡng 100; SpO2 94% dưới 95%.",
    "recommended_actions": [
      "Đo lại chỉ số sau 15 phút",
      "Nghỉ ngơi tại chỗ"
    ]
  }
}
```

Detail-only keys (in addition to the list-item keys):

| Key | Type | Notes |
| --- | --- | --- |
| `explanation` | `string` | Free-text rationale shown in the detail header. |
| `xai_explanation` | `string` | **Deprecated alias of `explanation`** since `v0.1`. Removal scheduled for Phase 6. |
| `features` | `dict[str, any]` | Raw feature values fed into the model. |
| `feature_importance` | `dict[str, float]` | **Deprecated** since `v0.1` — subset of `breakdown[*].contribution_score`. Removal scheduled for Phase 6. |
| `breakdown` | `FactorBreakdownResponse[]` | Per-feature drill-down — see section 5. |
| `recommendations` | `string[]` | Full list of recommendations. |
| `recommendation_preview` | `string[]` | First 2 recommendations (for collapsed view). |
| `snapshot` | `SnapshotMetricsResponse` | Vitals captured at the moment the score was produced. |
| `model_version` | `string` | Defaults to `"1.0"`; populated as `"model_api_v1"` once the model API answers. |
| `algorithm` | `string` | Defaults to `"unknown"`; populated by the SHAP/AI pipeline. |
| `ai_explanation` | `AiExplanationResponse \| null` | Optional GenAI block (short text + clinical note + actions). |

---

## 4. `RiskHistoryResponse` — history screen

Returned by `GET /mobile/analysis/risk-history`.

```json
{
  "range": "7d",
  "summary": {
    "average_score": 57.4,
    "highest_score": 62.0,
    "lowest_score": 51.0,
    "delta_vs_previous_period": -3.5,
    "trend_points": [55, 56, 57, 58, 59, 58, 58]
  },
  "items": [
    {
      "report_id": 42,
      "risk_score": 58.0,
      "score": 58.0,
      "health_score": 42.0,
      "risk_level": "medium",
      "display_status": "Cần theo dõi",
      "analyzed_at": "2026-04-27T08:00:00Z",
      "reason_preview": "Nhịp tim cao",
      "is_stale": false
    }
  ],
  "page": 1,
  "limit": 20,
  "has_more": false
}
```

| Key | Type | Notes |
| --- | --- | --- |
| `range` | `string` | `"7d"` \| `"30d"` \| `"90d"`. |
| `summary` | `RiskHistorySummaryResponse` | Aggregates across the requested window. |
| `items` | `RiskHistoryItemResponse[]` | Paginated list of per-report rows. |
| `page` | `int` | 1-indexed. |
| `limit` | `int` | Page size (1..100). |
| `has_more` | `bool` | `true` when the next page exists. |

`RiskHistoryItemResponse` mirrors the list item but with `report_id` /
`analyzed_at` / `reason_preview` instead of the full report payload, and
also carries the `risk_score` + `score` duplication that Phase 1 will resolve.

---

## 5. Nested DTOs

### 5.1 `TopFactorResponse`

```json
{
  "key": "heart_rate",
  "label": "Nhịp tim",
  "impact": 0.42,
  "direction": "risk_up",
  "reason": "Nhịp tim cao hơn bình thường",
  "feature_value": "112 bpm"
}
```

| Key | Type | Notes |
| --- | --- | --- |
| `key` | `string` | Stable feature key (`heart_rate`, `spo2`, …). |
| `label` | `string` | Localized display label. |
| `impact` | `float` | Magnitude in the SHAP-style contribution. |
| `direction` | `string` | `risk_up` \| `risk_down` \| `""`. |
| `reason` | `string` | Short Vietnamese explanation. |
| `feature_value` | `string` | Pre-formatted value with unit. |

### 5.2 `FactorBreakdownResponse`

```json
{
  "key": "spo2",
  "label": "SpO₂",
  "contribution_score": 0.31,
  "impact_level": "medium",
  "value": "94",
  "unit": "%",
  "route_target": "vitals/spo2",
  "direction": "risk_up",
  "reason": "SpO2 dưới 95% kéo dài"
}
```

| Key | Type | Notes |
| --- | --- | --- |
| `contribution_score` | `float` | Same magnitude semantics as `TopFactorResponse.impact`. |
| `impact_level` | `string` | `low` \| `medium` \| `high`. |
| `route_target` | `string` | Mobile deep-link target for the "open detail" button. |

### 5.3 `AiExplanationResponse`

```json
{
  "short_text": "Nhịp tim và SpO2 cần theo dõi sát.",
  "clinical_note": "HR 112 bpm vượt ngưỡng 100; SpO2 94% dưới 95%.",
  "recommended_actions": [
    "Đo lại chỉ số sau 15 phút",
    "Nghỉ ngơi tại chỗ"
  ]
}
```

### 5.4 `SnapshotMetricsResponse`

```json
{
  "heart_rate": 112,
  "spo2": 94,
  "sys_bp": 128,
  "dia_bp": 82,
  "body_temp": 36.9,
  "hrv": 42,
  "map_val": 97
}
```

`body_temp` is a `float`; the rest are `int` defaults to `0` when missing.

---

## 6. Deprecated fields — Phase 1 status

Phase 1 has formalised the canonical / deprecated split below. Each
deprecated field still ships on the wire (no breaking change for older
Flutter binaries) but is now:

- Marked `deprecated=True` in the Pydantic schema, so OpenAPI surfaces it.
- Guarded by a [`TestDeprecatedFieldInvariants`](../tests/contract/test_mobile_risk_dto_snapshot.py)
  invariant test that asserts the deprecated value is fully reconstructible
  from the canonical source.
- Read with a canonical-first fallback in the Flutter parser
  (`risk_analysis_repository.dart`), so a future canonical-only payload
  parses cleanly.

| Deprecated field | Canonical source | Owner DTO | Invariant guard |
| --- | --- | --- | --- |
| `risk_score` | `score` | `RiskReportResponse`, `RiskReportDetailResponse`, `RiskHistoryItemResponse` | `risk_score == score` |
| `health_level` | `display_status` | `RiskReportResponse`, `RiskReportDetailResponse` | `display_status` is required and non-empty |
| `key_features` | `top_factors[].key` | `RiskReportResponse` | `key_features == [f.key for f in top_factors]` |
| `xai_explanation` | `explanation` | `RiskReportDetailResponse` | `xai_explanation == explanation` |
| `feature_importance` | `breakdown[*].contribution_score` | `RiskReportDetailResponse` | `set(feature_importance) ⊆ {b.key for b in breakdown}` |

### Why we did not drop the fields in Phase 1

Removing a key is a **breaking change** for any older Flutter binary still
parsing the deprecated alias. Phase 6 will introduce the
`X-Risk-Contract-Version` header so the backend can:

1. Inspect the inbound version header.
2. Skip emitting the deprecated alias when the client opts in to the new
   version.
3. Continue dual-emitting for older clients during the deprecation window.

When that infrastructure lands, dropping the deprecated keys becomes a
single-PR change driven by the invariant tests above:

1. Remove the deprecated field from `backend/app/schemas/monitoring.py`.
2. Remove the matching `EXPECTED_*_KEYS` entry in
   `backend/tests/contract/test_mobile_risk_dto_snapshot.py`.
3. Remove the matching invariant test (it would otherwise fail because the
   field no longer exists).
4. Drop the canonical-first fallback in `risk_analysis_repository.dart`.
5. Bump the **Baseline version** at the top of this file (`v0.2` → `v1.0`).

---

## 7. Adapter layer + DTO builders — Phase 3 architecture

The DTO construction code is extracted out of `MonitoringService` into a
dedicated builder module so the canonical/deprecated mirroring lives at
one site instead of being repeated at every call site, and the input is a
typed dataclass rather than a stringly-typed dict.

| Builder | Returns | Used by |
| --- | --- | --- |
| `build_risk_report` | `RiskReportResponse` | `MonitoringService.get_risk_reports` |
| `build_risk_report_detail` | `RiskReportDetailResponse` | `MonitoringService.get_risk_report_detail` |
| `build_risk_history_item` | `RiskHistoryItemResponse` | `MonitoringService.get_risk_history` |

Each builder is a pure function of:

- a frozen `NormalizedRiskRow` dataclass (see
  `backend/app/services/normalized_risk_row.py`) — explicit, finite field
  set; immutable; supports `dataclasses.replace` for tests;
- already-computed dependencies (top factors, breakdown, snapshot, AI
  explanation, trend, previous score) passed as keyword arguments.

This means the builders are unit-tested in isolation
(`backend/tests/test_risk_report_builder.py`) without a database fixture, and
the `MonitoringService` methods become thin orchestrators that fetch +
assemble inputs, then delegate construction.

### Why an extra module instead of static methods on `MonitoringService`

- The builders need to be importable from future risk-pipeline producers
  (e.g. the SHAP explanation pipeline, the model-API client) without pulling
  in the full `MonitoringService` and its DB coupling.
- Pure DTO construction logic does not belong in a service class whose
  primary concern is data access.
- It makes the Phase 6 removal sequence trivial: deleting a deprecated field
  becomes a single edit per deprecated field at the builder level.

### Why a frozen `NormalizedRiskRow` dataclass instead of `dict[str, Any]`

- The set of fields produced by the normaliser is now explicit and finite;
  adding a field requires touching the dataclass, which forces a code
  review on every consumer.
- Builders and helpers (`MonitoringService._compute_trend_7d` etc.) get
  attribute access with full IDE / mypy support instead of stringly-typed
  dict lookups.
- `frozen=True` + `slots=True` give us immutability at the boundary
  between the data layer and the DTO layer, plus a small memory win on
  the hot path. Tests use `dataclasses.replace` for variations.
- The dataclass is intentionally **plain** (not Pydantic) because it
  never crosses the API boundary; we don't need Pydantic's
  serialisation / validation cost at this internal layer.

### Phase 3b — adapter layer (landed in v0.4)

The plan's full Phase 3 extracted three adapters out of
`risk_alert_service.py`:

| Adapter | Responsibility | Static methods |
| --- | --- | --- |
| `ModelApiHealthAdapter` | Inference-layer boundary | `to_record(payload) -> dict`, `from_response(resp, *, defaults_applied, feature_snapshot) -> NormalizedExplanation`, `from_local_inference(RiskInferenceResult, ...) -> NormalizedExplanation` |
| `RiskPersistenceAdapter` | Database write boundary | `build_features_json(...) -> dict`, `persist(db, ...) -> RiskScore` |
| `MobileRiskDtoAdapter` | Mobile read boundary | Already exists as `app/services/risk_report_builder.py` (relocation deferred — would only churn imports without changing behaviour) |

The two new adapters share the `NormalizedExplanation` dataclass — the
**write-path** counterpart of `NormalizedRiskRow` (which is the
**read-path** type). Keeping the two distinct prevents a producer /
consumer cycle in the data model and lets each side evolve independently.

After the extraction, `risk_alert_service.calculate_device_risk` is
**99 LOC** (was 263) and the whole file is **393 LOC** (was 773). The
function is now pure orchestration: cooldown check → vitals fetch →
inference (model-api or local fallback) → persistence → alert dispatch.

Behaviour is **verbatim-preserved**:

- Medical defaults in `to_record` (75 bpm / 16 rpm / 36.6 °C / 98% /
  120-80 mmHg / 165 cm / 65 kg / 50 ms HRV) and the gender int 0/1 +
  `height_m` output convention.
- `_default_recommendations` copy and counts (3 for critical, 2 for
  medium, 2 for low) — pinned by
  `tests/test_shap_explanation_contract.py::TestDefaultRecommendations`.
- `_build_explanation_text` English copy with backticked backend label —
  matches what existing `risk_explanations` rows already store on disk.
- `_feature_importance_from_top_features` defaults missing impact to
  `0.0` and rounds to 4 decimals.
- `_build_feature_importance` (snapshot path) takes `abs(value)` and
  rounds to 4 decimals.

---

## 7k. Fall critical push — Phase 4B-full slice 2d

The push fan-out for freshly-detected falls. Distinct from the
existing SOS push (``send_sos_push_alerts``) so the mobile fall
handler can branch cleanly on ``type='fall_alert'`` without
inheriting the SOS state machine that doesn't apply to a "the AI
just saw a fall — confirm or dismiss" workflow.

### Backend — ``PushNotificationService.send_fall_critical_alert``

Signature::

    send_fall_critical_alert(
        db, *,
        recipient_user_ids, fall_event_id, fall_event_uuid,
        title, body, confidence,
        notification_id_by_user=None,
    )

Builds one FCM message per active push token of every recipient.
Always **takeover** (``notification=None``, data-only) so the OS
never auto-renders a banner that bypasses the full-screen alert
flow — false negatives on a real fall are dangerous, so we route
everything through the Flutter background handler.

### Push payload contract

The mobile ``parseFallEventFromPushData`` parser pins these data fields:

| Field | Type | Notes |
|---|---|---|
| ``type`` | string | Always ``"fall_alert"``. Discriminator that the mobile handler keys on. |
| ``event_type`` | string | Always ``"fall_detected"`` (legacy compatibility with the existing ``is_sos_emergency_takeover`` allow-list). |
| ``fall_event_id`` | string | Numeric id of the ``fall_events`` row. Mobile parses to int; unparseable → drop the push. |
| ``fall_event_uuid`` | string | Stable UUID for FCM-retry dedup. Empty → drop the push. |
| ``confidence`` | string | 3-decimal float. Mobile clamps to ``[0, 1]``; unparseable → 0.0. |
| ``title`` / ``body`` | string | Vietnamese alert copy. |
| ``notification_id`` | string | DB notification row id, or empty string when not pre-created. |
| ``created_at`` | ISO-8601 | Server-side push creation time (NOT the fall detection time). |
| ``click_action`` | string | Always ``"FLUTTER_NOTIFICATION_CLICK"`` so Android tap routes through ``onMessageOpenedApp``. |

### Mobile — ``lib/core/notifications/fall_event_handler.dart``

Three helpers:

* ``parseFallEventFromPushData(data)`` — turns the FCM string-only
  data envelope back into a typed [FallEvent] stub. Forward-compatible:
  unknown ``type`` returns null (lets the existing SOS / risk handlers
  branch on theirs); missing required fields return null; confidence
  clamps to ``[0, 1]``; unparseable confidence falls back to 0.0.
* ``presentFallAlert(context, event)`` — pushes [FallAlertScreen] onto
  the Navigator with a fullscreen-dialog route. Idempotent guard
  against FCM-retry double-pushes via ``replaceCurrent`` flag.
* ``hydrateFallEvent(stub, repository)`` — best-effort fetch of the
  full server-side row (GPS, address, model_version, features). On
  transport failure returns null and the synthetic stub stays
  visible — better than failing the alert because the network
  hiccupped.

### Why ``confidence`` lands in the push payload

The mobile UI uses confidence to decide:

* High confidence (≥ 0.85) → auto-open ``FallAlertScreen`` immediately.
* Medium confidence (0.6 – 0.85) → show a banner with "Phát hiện ngã"
  badge + tap to view (less aggressive UX since the model might be
  wrong).
* Low confidence (< 0.6) → don't push at all (the backend's IMU
  route would not have triggered a fall_events row in the first
  place).

Embedding it in the push avoids a hydrate round-trip just to make
the auto-open vs banner decision.

### Why no wire-version bump

The FCM data envelope is **not** a DTO contract surface — it's a
private push protocol between this backend and this Flutter app.
``RISK_CONTRACT_VERSION`` covers the read-path JSON contract
(``/risk-reports*`` etc.), and the version checker
(``RiskContractVersion`` mobile inspector) only inspects HTTP
response headers. Pushing a new field on FCM data triggers no
version mismatch warning.

### What's deferred

The two **wiring** changes are deliberately not in this slice:

* **IMU window route → push trigger**: extending
  ``POST /mobile/telemetry/imu-window`` to call
  ``send_fall_critical_alert`` after persisting a high-confidence
  fall. Touches the route handler + adds a recipient resolver that
  walks ``devices.user_id`` + caregiver relationships. Better as
  its own slice with focused tests.
* **Mobile notification handler hookup**: wiring
  ``parseFallEventFromPushData`` into the existing
  ``_handleFcmForegroundMessage`` and ``_handleRemoteMessageOpen``
  in ``notification_runtime_service.dart``. Touches a
  multi-thousand-line file with intricate routing; safer as its
  own focused diff.

The primitives (backend method + mobile parser + presenter) are
fully tested standalone; the wiring is a follow-up that operates
on top.

---

## 7j. Mobile fall-events read surface — Phase 4B-full slice 2c (backend half)

The simulator (slice 2b) and the v0.8 ingest route already create
``fall_events`` rows on disk; this slice exposes them on the
mobile-facing read path so the Flutter ``lib/features/fall/`` module
(slice 2c mobile half) can render the alert + history screens.

### Routes

| Method | Path | Behaviour | Slice |
|---|---|---|---|
| `GET`  | `/mobile/fall-events` | Paginated list, newest-first. ``limit≤100``, ``offset≥0``. | 2c |
| `GET`  | `/mobile/fall-events/{id}` | One event by id. **404 on either "doesn't exist" or "not yours"** to avoid the enumeration leak. | 2c |
| `POST` | `/mobile/fall-events/{id}/dismiss` | Mark as user-cancelled with optional ``reason`` (``≤255`` chars). Idempotent. | 2c |

All three routes resolve the user via ``X-Target-Profile-Id`` (existing
relationship resolver) and JOIN through ``devices.user_id`` so a
caregiver fetching the elder's fall events Just Works without any new
auth code.

### Why ``status`` is derived server-side

``fall_events`` stores four raw workflow columns (``user_responded_at``,
``user_cancelled``, ``sos_triggered``, ``user_notified_at``); the
mobile ``FallEventResponse`` carries a single ``status`` string the
state-machine projection of those columns:

| Precedence | Condition | ``status`` |
|---|---|---|
| 1 | ``sos_triggered=True`` | ``escalated`` |
| 2 | ``user_cancelled=True`` | ``dismissed`` |
| 3 | ``user_responded_at IS NOT NULL`` | ``confirmed`` |
| 4 | otherwise | ``detected`` |

Order matters because a single row can have multiple booleans set
(e.g. user dismissed *after* auto-SOS already fired); the most decisive
state wins. Done server-side so a future contract bump that reorders
the precedence doesn't require a Flutter binary update.

### Why dismiss locks the row

``POST .../dismiss`` uses ``SELECT FOR UPDATE`` so a Flutter client
that double-taps "Tôi ổn" doesn't produce two conflicting writes.
Idempotent in spirit: re-dismissing refreshes ``user_responded_at``
and overwrites ``cancel_reason`` if a new one was supplied. The
service raises :class:`SQLAlchemyError` on DB failure (route layer
returns 500) rather than swallowing — silently keeping the alert
active in the UI would be a safety regression.

### Why no contract version bump

The risk-DTO contract version applies to the `/risk-reports*` +
`/risk-history` + `/health-report` surfaces (see
``RISK_CONTRACT_ROUTE_PREFIXES``). Fall events are a separate surface
with its own evolving shape; bumping ``RISK_CONTRACT_VERSION`` for an
addition outside that surface would falsely signal a risk-DTO change
to mobile clients. The fall-events contract is pinned by the snapshot
tests in ``tests/test_fall_events_routes_http.py`` instead.

### What's deferred to slice 2c (mobile half) and slice 2d

- **Mobile UI** (slice 2c mobile): ``lib/features/fall/`` module —
  entities, repository, provider, ``FallAlertScreen`` (full-screen
  countdown + dismiss / confirm), ``FallHistoryScreen`` (timeline
  list).
- **Push channel** (slice 2d): ``fall_critical`` FCM channel that
  wakes the screen on incoming fall events. Wires into the existing
  ``notification_runtime_service.dart`` foreground/opened handlers.

---

## 7i. Fall classifier quality harness — Phase 4B-full slice 2a

Plan §4B.3 §I require the fall route shipped in v0.8 to clear three
quality thresholds before any additional caller (simulator dispatch,
mobile alert UI, push channel) is wired in. Slice 2a delivers the
gate.

### Acceptance thresholds

| Metric | Threshold | Why |
|---|---|---|
| Sensitivity (TP / (TP + FN)) | **≥ 0.90** | False negatives on real falls are dangerous — a missed alert can mean an untreated injury for an elderly user. |
| Specificity (TN / (TN + FP)) | **≥ 0.85** | Excessive false alarms cause alarm fatigue and erode trust. |
| F1 | **≥ 0.87** | Combined precision-recall balance check. |

A failing run halts Phase 4B-full landings until the fall model is
retrained or the dataset is re-curated. Production protection: the
fall route can ship behind a `FALL_INFERENCE_ENABLED=0` feature flag
until the gate clears.

### Layout

```
backend/tests/eval/
├── etl_up_fall.py                     # raw UP-Fall CSV -> labelled JSONL
├── fixtures/up_fall_windows.jsonl     # 126 windows committed to git
├── test_etl_up_fall.py                # 21 always-on ETL unit tests
├── test_fall_classifier_quality.py    # gated harness (RUN_EVAL=1)
└── reports/                           # dated JSON reports (gitignored)
```

### Why UP-Fall, not PAMAP2

The original plan listed both UP-Fall (positive class) and PAMAP2
(negative class) as inputs. **Audit found PAMAP2 is not present in the
simulator repo** (`Iot_Simulator_clean/datasets/04_activity/PAMAP2/`
exists but `PAMAP2_Raw/` is empty). UP-Fall already provides both
classes — A01–A05 are falls, A06–A11 are ADLs (walking, standing,
sitting, picking up, jumping, laying) — so the harness has positive +
negative samples without a second dataset.

If PAMAP2 data is added later, drop a parallel `etl_pamap2.py` +
fixture under `tests/eval/` and extend the harness's input loader to
combine both. The threshold gate logic stays identical.

### Why pre-pad short fall trials

The 440 KB `UP-Fall_Dataset.zip` shipped in the simulator repo is a
**curated mini-version** of the full UP-Fall Detection Dataset. Fall
trials (A01–A05) have exactly **40 samples each**, but the model-api
requires `fall_min_sequence_samples = 50`. The ETL pre-pads short
trials with the first sample value (gravity-only, motionless) to
simulate the brief pre-event stillness a production sliding window
catches anyway. Tradeoffs considered:

| Option | Why rejected |
|---|---|
| Linear upsampling 40 → 50 samples | Fabricates dynamics — the model would see motion that didn't exist. |
| Zero-padding | The model can learn to recognise the synthetic flat region. |
| Mirror padding (reflect last K) | Doubles motion artefacts — unnatural. |
| Override `fall_min_sequence_samples=40` for eval | Eval results stop reflecting production behaviour. |
| **Pre-pad with first sample** ✅ | Realistic — production's sliding window IS catching pre-fall stillness + the fall itself in a single 50-sample window. |

The ETL summary reports `padded_windows` so a future contributor with
the full UP-Fall dataset can re-run the ETL and see the padding ratio
drop to zero automatically.

### Cross-repo dependency

The ETL reads from
`d:\DoAn2\VSmartwatch\Iot_Simulator_clean\datasets\05_fall\UP-Fall\UP-Fall_Raw\`
via a relative path computed from the test file's location. If the
simulator repo isn't cloned alongside `health_system`, regenerating
the fixture fails with a clear `FileNotFoundError`. The committed
JSONL fixture means **the always-on tests + the gated harness both run
without the simulator repo present** — only re-running the ETL needs
it.

### Running the gated harness

```bash
# Terminal 1 — start model-api
cd healthguard-model-api
python -m uvicorn app.main:app --host 0.0.0.0 --port 8001

# Terminal 2 — run the gated test
cd health_system/backend
$env:RUN_EVAL = "1"
python -m pytest tests/eval/test_fall_classifier_quality.py -v -s
```

Output is a dated `reports/confusion_matrix_<UTC-timestamp>.json`
with the full confusion matrix + per-window predictions for debugging.
Reports are gitignored; the operator decides which to keep for
trending.

### What's deferred to slices 2b–2d

- **Simulator dispatch**: slice 2b — `request_fall_prediction` on
  `HealthGuardAPIClient` so a simulated fall actually hits the live
  fall route (currently the harness is the only caller).
- **Mobile fall alert UI**: slice 2c — `lib/features/fall/` module +
  `GET /mobile/fall-events` routes.
- **Push channel**: slice 2d — `fall_critical` FCM channel + handler
  wired into `notification_runtime_service.dart`.

---

## 7h. Audience-payload cache — Phase 7 architecture

Phase 7 closes the plan's §E.7 cache requirement: cache the assembled
mobile DTOs on the same row that produced them so repeat detail
requests serve the cached bytes instead of re-running SHAP →
breakdown → builder. Lazy write-through, audience-keyed, contract-version-pinned.

### Cache shape

The new column `risk_explanations.audience_payload_json` (`JSONB`,
nullable) stores a small dict keyed by audience profile:

```json
{
  "patient": {
    "contract_version": "0.5.0",
    "payload": { ...RiskReportDetailResponse.model_dump()... }
  },
  "clinician": {
    "contract_version": "0.5.0",
    "payload": { ...RiskReportClinicianResponse.model_dump()... }
  }
}
```

Both keys are optional — a row may legitimately have only `patient`
populated until the first clinician request lands. The persistence
adapter does NOT pre-populate the cache; the read path is the only
writer.

### Read path — `MonitoringService.get_risk_report_*_detail`

Unified pseudocode (both patient + clinician variants follow this):

```python
row = SELECT ... re.audience_payload_json FROM risk_scores rs JOIN ...
if cached := _read_audience_cache(row, audience, ResponseModel):
    return cached  # cache hit — short-circuits SHAP + breakdown + builder
result = ResponseBuilder(**_build_detail_inputs(patient_id, row, db))
_write_audience_cache(db, row, audience, result)  # best-effort
return result
```

### Cache invalidation

`RISK_CONTRACT_VERSION` is the cache key suffix. Any future contract
bump (the constant in `app/core/risk_contract.py`) **automatically
invalidates every cached row** — `_read_audience_cache` treats a
mismatched `contract_version` as a miss and rebuilds. **No manual
flush job is needed.**

| Future change | Triggers cache rebuild? |
|---|---|
| Bump `RISK_CONTRACT_VERSION` (any reason) | YES — every entry treated as miss |
| Add a field to `RiskReportDetailResponse` | YES if the bump is honoured (it must be — see plan §E.6) |
| Builder logic change without contract bump | NO — stale entries leak. **Bump the version whenever the builder changes.** |

The "builder change without bump" failure mode is documented in the
contract-version comment in `risk_contract.py` so it's the first thing
a future contributor sees.

### Cache write atomicity + failure handling

The write is a single `UPDATE risk_explanations SET
audience_payload_json = ... WHERE id = ?` issued **after** the DTO has
already been built in memory. The flow:

1. Build the DTO via the existing assembly path.
2. Merge the new audience entry into whatever's already in the column
   (so a clinician write doesn't erase an existing patient entry).
3. Try the UPDATE.
4. **On any DB error**: `db.rollback()` + log via `logger.exception`.
   The freshly-built DTO is still returned to the caller.

This makes the cache a strictly **best-effort optimisation** — a
broken cache write never affects request semantics. The next request
will rebuild + try again.

### Observability

Every read emits a `record_timing("build_dto", ...)` record with these
tags:

| Tag | Values | Meaning |
|---|---|---|
| `audience` | `patient` / `clinician` | Which DTO was requested |
| `cache` | `hit` / `miss` | Did we serve cached bytes? |
| `reason` (miss only) | `no_cache_column` / `no_audience_entry` / `version_mismatch` / `malformed_payload` / `payload_validate_failed` | Why we missed |

Hit-rate dashboards can plot `cache="hit"` count / total count grouped
by `audience` to spot regressions. The `reason` tags help triage
unexpected miss spikes (e.g. a sudden surge of `version_mismatch`
means a deploy bumped `RISK_CONTRACT_VERSION`).

### Disk usage estimate

A typical detail payload `model_dump_json()` runs ≈ 4–8 KB depending
on the SHAP detail size. Worst case at 100k users × 10 detail reads ×
2 audiences ≈ 16 GB. **Acceptable for now**; future TTL-based cleanup
or a separate cache table is a follow-up workstream when actual
production volumes warrant it.

### What's still deferred to a future "Phase 7-extended"

- **TTL eviction** — currently the cache is keyed only by `contract_version`. Old rows accumulate forever until the contract bumps.
- **Pre-population on persist** — the persistence adapter could pre-build both audience payloads after a fresh inference. Skipped because the read path needs `previous_score` / `trend_7d` / `breakdown` which are read-time concerns; pre-building them at write-time would require duplicating those queries. The lazy approach is a strict win.
- **List-route cache** — `get_risk_reports` (list view) still rebuilds every list item DTO from scratch. Plan §E.7 only calls for the detail route; lists are typically rendered once per session anyway.
- **Cross-row aggregation cache** — `get_risk_history_summary` recomputes highest/lowest/average on every call. Out of Phase 7 scope.

---

## 7g. Audience profiles + clinician gate — Phase 5 architecture

Phase 5 introduces the trust-boundary split the plan calls for in
§D.3 / §F.1: raw SHAP and the upstream model-api request id are
**clinical** signals that should not surface on the patient screen by
default. Flipping a query param + role check is sufficient gate; no
new RBAC infrastructure was needed because the audit found
`users.role` already exists and is populated.

### Route — `GET /mobile/analysis/risk-reports/{id}?audience=...`

| Audience | Who can call | Returns | Wire version |
| --- | --- | --- | --- |
| `patient` (default) | Any authenticated user | `RiskReportDetailResponse` (unchanged from v0.9) | `0.5.0` |
| `clinician` | `user.role` in `CLINICIAN_ROLES` (`{"clinician", "admin"}`) | `RiskReportClinicianResponse` (extends patient + `shap_details` + `model_request_id`) | `0.5.0` |

* `audience=patient` is the default so every Flutter binary built
  against `v0.4.0` keeps getting the exact same shape.
* `audience=clinician` from a user whose `role` is NOT in
  `CLINICIAN_ROLES` returns **HTTP 403** — gated by
  `require_clinician_audience` at the FastAPI dependency layer so the
  handler never executes with an unauthorised audience.
* Unauthenticated requests get **HTTP 401** before the gate runs (the
  existing `HTTPBearer` dependency on `get_current_user`).

OpenAPI exports both DTOs in `components.schemas` and the route
response is an `anyOf: [RiskReportDetailResponse, RiskReportClinicianResponse]`
so codegen consumers can model the audience-conditioned response.

### Read-path additions

The Phase 5 SQL change adds two columns to the LATERAL join in
`MonitoringService.get_risk_reports` and
`MonitoringService.get_risk_report_detail`:

| Column | Source | Persisted by | Now read by |
| --- | --- | --- | --- |
| `shap_details_json` | `risk_explanations.shap_details_json` (JSONB) | Phase A SHAP migration + Phase 3b `RiskPersistenceAdapter` | Phase 5 — only surfaced on `RiskReportClinicianResponse.shap_details` |
| `model_request_id` | `risk_explanations.model_request_id` (VARCHAR(36)) | Phase 2 (`20260427_model_request_id.sql` + persistence adapter) | Phase 5 — only surfaced on `RiskReportClinicianResponse.model_request_id` |

`NormalizedRiskRow` carries both; the patient builder
(`build_risk_report_detail`) intentionally ignores them, the clinician
builder (`build_risk_report_clinician_detail`) wraps the patient
result and adds them at the top level.

### Why `users.role` instead of a full RBAC table

The plan §I.1 flagged "RBAC cho clinician role: hiện có chưa? Nếu chưa,
Phase 5 phải thêm role table + middleware → effort tăng ~1 ngày".
Audit found:

- `users.role` is already declared (`String(20)`, default `"user"`).
- Existing values referenced in code: `'patient'`, `'user'`, `'admin'`.
- No CHECK constraint on `users.role` — adding `'clinician'` is a
  data change, not a schema change.

So Phase 5 ships with a tiny allow-list (`CLINICIAN_ROLES = {"clinician",
"admin"}`) that satisfies plan acceptance ("clinician profile chỉ
available cho user role có quyền y tế") without adding RBAC plumbing.
Production assignment of `role='clinician'` happens through the existing
admin user-management flow — out of Phase 5 scope.

### What's deferred to a future "Phase 5-extended"

- **Mobile clinician toggle UI**: a settings switch that flips
  `audience=clinician` on the API client. Phase 8 territory (now landing — see slice 4 of the final-completion plan).
- **SHAP detail mobile screen**: currently no Flutter surface for raw
  SHAP. Plan §G.3 reserves this for clinician audience (Phase 8 slice 4b).
- **Doctor / nurse roles**: trivial one-line addition to
  `CLINICIAN_ROLES` once those roles are minted.

---

## 7f. Sleep risk ingest — Phase 4A-thin architecture

Phase 4A in the plan is a full sleep pipeline alignment: backend route +
simulator dispatch + mobile sleep-risk surface. The version landed
under `v0.9` is **only the backend slice**, completing the symmetry
with Phase 4B-thin so all three model-api endpoints (health, fall,
sleep) have backend orchestration + breaker-wrapped clients.

### Why "thin" subset

The audit (this branch's `git log -p` against `develop`) found that
the plan's claim "simulator bypasses backend → port 8001 direct" was
**partially stale**: the simulator's `SleepAIClient` is dead code (the
hard-coded path `/predict` doesn't match model-api's
`/api/v1/sleep/predict`, so the call always 404s and the heuristic
fallback in `SleepService._compute_sleep_score_from_summary` is what
actually runs in production). Adding the backend slice now means:

- A future simulator update that wants AI-backed sleep scoring has a
  stable, tested route to call.
- A future `lib/features/sleep_risk/` mobile feature module can read
  sleep risk from the existing `MonitoringService.get_risk_history`
  surface (filtered by `risk_type='sleep'`) without the route's
  shape needing to change.
- Bridging the dead-code gap exposes that the heuristic path is the
  authoritative one until further notice; product can decide if the
  AI path should be enabled at all.

### Route — `POST /mobile/telemetry/sleep-risk`

| Concern | Behaviour |
| --- | --- |
| Auth | Internal-service (no JWT); same trust model as `/imu-window` and `/alert`. Caller passes `db_device_id` + `db_user_id` for FK resolution. |
| Payload | `SleepRiskRequest` (`backend/app/schemas/sleep_telemetry.py`) — wraps a verbatim `SleepRecord` (40+ fields). Caller responsibility: every field must be populated; silently defaulting to 0 would bias the model toward "perfect sleep". |
| Upstream call | `ModelApiClient.predict_sleep(...)` — own `model_api_sleep` breaker so a degraded sleep model can't silence health or fall. |
| Score inversion | `SleepRiskAdapter.from_response` writes `risk_score = 100 - predicted_sleep_score`. A great-sleep night (sleep_score=85) lands as risk_score=15; a bad-sleep night (sleep_score=20) lands as risk_score=80. |
| Persistence | Existing `RiskPersistenceAdapter.persist` with `risk_type='sleep'` — same code path as vitals risk. The migration `20260427_sleep_risk_type.sql` relaxes the `check_risk_type` CHECK to include `'sleep'`. |
| Failure | `predict_sleep` returns `None` → `status="model_unavailable"`, no row written. Sleep risk is not worth guessing at when the model is down. |

### Score inversion rationale

Model-api uses sleep_score 0–100 where **high=good**. The
`risk_scores` table uses score 0–100 where **high=worse** (so the
existing risk-trend chart can plot vitals risk and sleep risk on the
same axis without per-domain branching). The inversion happens at the
adapter boundary so the persistence layer never has to know about
domain-specific score conventions.

Concrete cases (pinned by `tests/test_sleep_risk_adapter.py::TestScoreInversion`):

| `predicted_sleep_score` | Persisted `risk_score` | Risk level |
| --- | --- | --- |
| `100.0` (perfect) | `0.0` | low |
| `85.0` (good) | `15.0` | low |
| `50.0` (boundary) | `50.0` | medium |
| `20.0` (poor) | `80.0` | critical |
| `0.0` (no sleep) | `100.0` | critical |
| missing / unparseable | `100.0` | medium (default) |

Defaulting a missing score to `risk_score=100` is deliberate: it
surfaces "we got nothing useful from the model" as critical risk
rather than silently treating it as healthy sleep. The accompanying
`risk_level` defaults to `medium` (the only level that doesn't claim
strong knowledge in either direction).

### What's deferred to Phase 4A-full

- **Mobile sleep-risk surface**: the existing `lib/features/sleep_analysis/`
  module reads from `/mobile/telemetry/sleep` (heuristic-scored
  persistence). A new sleep-risk surface (or `riskType='sleep'`
  filtering on the existing risk-history view) is product-shaped
  work — mobile UX needs to decide whether sleep risk lives in the
  same risk timeline as vitals or gets its own card.
- **40-field SleepRecord mapper on the simulator side**: today's
  simulator only tracks ~10 of the 40+ fields the model-api expects.
  A safe mapper (no zero-defaults that bias the model) needs sleep
  domain expertise.
- **Cut-over diff-log**: plan §4A.2 calls for running the new path
  parallel to the existing heuristic for ~100 sessions and cutting
  over once the diff < 1%. Operational work.
- **Killing the dead `SleepAIClient` path on the simulator**: now
  that the backend slice is in place, the dead port-8001 client can
  be removed. Cross-repo work, deferred for the same session.

---

## 7e. IMU window ingest — Phase 4B-thin architecture

Phase 4B in the original plan is a full fall pipeline: backend route +
simulator dispatch + mobile alert UI + push channel + a confusion-matrix
harness running against UP-Fall + PAMAP2 datasets. The version landed
under `v0.8` is **only the backend slice** — enough that a future
simulator / mobile integration can call into a stable, tested route.

### Route — `POST /mobile/telemetry/imu-window`

| Concern | Behaviour |
| --- | --- |
| Auth | Internal-service (no JWT); same trust model as `/mobile/telemetry/vitals` and `/mobile/telemetry/alert`. Caller passes `db_device_id`; FK constraint on `fall_events.device_id` validates at write time. |
| Payload | `ImuWindowRequest` (`backend/app/schemas/fall_telemetry.py`) — verbatim port of model-api `FallPredictionRequest` plus `db_device_id`. The inner `data` array (one `SensorSample` per timestep) passes through to model-api unchanged. |
| Min window length | 20 samples at the FastAPI layer; the model-api may demand more (its `fall_min_sequence_samples` is the authoritative threshold) and a too-short window surfaces as `status="model_unavailable"` rather than an HTTP error. |
| Upstream call | `ModelApiClient.predict_fall(...)` — already breaker-wrapped (`model_api_fall` breaker) and timed (`model_api_call` stage) by Phase 7. |
| Success | Persist one `fall_events` row via `FallPersistenceAdapter`; return `status="ok"` + `fall_event_id` + `fall_probability` + `prediction_band` + `model_request_id`. |
| Failure | `predict_fall` returns `None` (breaker open / transport / non-200 / malformed body) → `status="model_unavailable"`, `fall_event_id=null`, **no row written**. The caller decides whether to retry. |

### Why no rule-based fallback for fall

The risk-pipeline pattern (`risk_alert_service`) falls back to a local
rule-based predictor when model-api is unavailable. Fall does **not**
follow that pattern in this slice because:

1. A rule-based fall predictor would need its own confusion-matrix
   harness to defend its sensitivity / specificity numbers; that's
   Phase 4B-full territory (plan calls for ≥0.90 sensitivity, ≥0.85
   specificity, F1 ≥0.87 against UP-Fall + PAMAP2).
2. Plan section F.3 frames fall as **alert-state**, not insight-state —
   uncertainty must be surfaced, not silently filled in.
3. False-negative cost (missed real fall) and false-positive cost
   (alarm fatigue → user disables notifications → next real fall
   missed) are both severe; defaulting to "no fall" or "fall" is
   strictly worse than "model_unavailable, retry".

### What's deferred to Phase 4B-full

- **Simulator-side dispatch**: `pre_model_trigger/healthguard_client.py`
  needs a new `request_fall_prediction(device_id, motion_window)` method
  that POSTs to this route. Today the simulator's
  `HealthGuardAPIClient` only has `request_prediction` for vitals.
- **Mobile fall alert UI**: full-screen overlay with 30s countdown +
  push-notification handler. Needs a new `lib/features/fall/` feature
  module (none exists today).
- **Push notification channel for fall**: highest-priority channel that
  can wake the device screen on Android.
- **Confusion-matrix harness**: `backend/tests/eval/test_fall_classifier_quality.py`
  with the dataset-driven sensitivity / specificity / F1 acceptance
  metrics from plan §4B.3.
- **Threshold sweep / ROC analysis**: per plan §4B.4.
- **Edge-case scenarios**: drop-device, vung-tay, ngồi-mạnh, etc., per
  plan §4B.5 — needs dataset access.

### Schema notes — `fall_events` reuse

The plan called for a richer `fall_events` schema (status state machine
`detected → confirmed → dismissed → escalated`, countdown timestamps,
`shap_details_json`). The existing table already has the core columns
(`device_id`, `detected_at`, `confidence`, `model_version`, `features`,
GPS, user-response workflow, SOS link). The features JSONB carries the
upstream `top_features` + `prediction` + `meta` blocks plus the
promoted `model_request_id` for log correlation, so no schema migration
is needed for this slice. Adding a state-machine column when Phase 4B-full
lands the countdown UI is a separate small migration.

---

## 7d. Persistence traceability — Phase 2 (focused) architecture

Phase 2 in the original plan is a full persistence-schema migration
(alembic, multiple new columns, backfill). The version landed under
`v0.7` is a focused subset — only the `model_request_id` column —
because:

- The `audience_payload_json` cache is purely Phase 5 prep; with no
  audience profiles yet, the column would be unused.
- Backfilling historical rows is impossible: the upstream request_id
  is not retained anywhere it could be reconstructed from.
- The column itself is forward-compatible (nullable, partial index on
  `IS NOT NULL`); the next deploy starts populating it for new model-api
  rows automatically.

### What's persisted

| Column | Type | Source | NULL when |
| --- | --- | --- | --- |
| `model_request_id` | `VARCHAR(36)` | `meta.request_id` from the model-api 6-layer response | The local rule_based / ONNX / LightGBM fallback path produced the row |

### Defensive parsing

`ModelApiHealthAdapter.from_response` applies four guards before
populating `NormalizedExplanation.model_request_id`:

1. **Type coerce** — `str()` so a numeric upstream value never crashes
   the SQLAlchemy write path.
2. **Trim** — `.strip()` so a whitespace-only value normalises to `NULL`.
3. **Truncate** — `[:36]` so the DB column never overflows.
4. **Blank → NULL** — empty strings collapse to `None` so the partial
   index stays empty for them.

### Pending ops work

- Apply `backend/migrations/20260427_model_request_id.sql` against the
  production database during the next migration window.
- Spot-check that ≥ 95 % of new rows produced via the model-api path
  populate the column once the migration is live (rule_based rows
  intentionally stay `NULL`).

---

## 7c. Resilience + observability — Phase 7 architecture

Phase 7 (reduced scope — see plan section E.7) adds two production
safety nets around the external model-api call site without changing
the wire format or the read-path DTOs.

### Circuit breaker — `backend/app/services/circuit_breaker.py`

A 70-line, hand-rolled, sync-only `CircuitBreaker` class with three
states:

```
CLOSED  --(N consecutive failures)-->  OPEN
OPEN    --(reset_timeout elapsed)-->   HALF_OPEN
HALF_OPEN --(success)-->               CLOSED
HALF_OPEN --(failure)-->               OPEN  (fresh window)
```

`ModelApiClient` instantiates **two** independent breakers:
`model_api_health` for `predict_health_risk` and `model_api_fall` for
`predict_fall`. A fall-endpoint outage must not silence health
predictions and vice versa.

Failure classification:

| Outcome | Trip breaker? | Why |
| --- | --- | --- |
| `httpx.ConnectError` / `ConnectTimeout` / `TimeoutException` | Yes | Outage symptoms — exactly what the breaker is for. |
| Other `httpx.HTTPError` | Yes | Transport-level error from a reachable but unhealthy upstream. |
| `response.status_code != 200` (4xx / 5xx) | Yes | A 5xx storm would otherwise drain the request thread pool. |
| Malformed JSON in 200 response | **No** | Reachable but speaking the wrong dialect; skipping won't help — fix the contract instead. |
| `results[0].status != "ok"` | No | Same — application-level no-data, not an outage. |

Configuration via env (with sensible defaults):

- `MODEL_API_BREAKER_FAILURES` — consecutive-failure threshold, default `5`.
- `MODEL_API_BREAKER_RESET_SECONDS` — reset-window duration, default `60`.

Process scope: each gunicorn / uvicorn worker tracks its own breaker
state. With ~5 failures per worker before tripping, an outage
amortises across the cluster within a handful of requests rather than
per-worker timeouts on every incoming request.

### Stage timing — `backend/app/observability/timing.py`

A tiny helper that emits one structured log line per timed block:

```python
with StageTimer("model_api_call", endpoint="health_predict"):
    response = client.post(...)
```

Four canonical stages are wired today:

| Stage | Where it's timed | Tags |
| --- | --- | --- |
| `build_record` | `risk_alert_service.calculate_device_risk` (around `ModelApiHealthAdapter.to_record`) | `device_id` |
| `model_api_call` | `ModelApiClient.predict_health_risk` and `predict_fall` | `endpoint` ∈ `{health_predict, fall_predict}` |
| `persist` | `risk_alert_service.calculate_device_risk` (around `RiskPersistenceAdapter.persist`) | `device_id`, `backend` |
| `build_dto` | (Reserved for Phase 7+: when audience-profiled DTO assembly lands.) | n/a |

Every event lands as an `INFO` log line with prefix `risk.timing` so a
downstream aggregator (cloud logging, Loki, ELK) can build histograms
and percentile dashboards without the backend carrying a metrics
runtime dependency. Tests subscribe via `subscribe_for_tests` for
deterministic capture.

The timer always fires, even when the wrapped block raises — outage
timing dashboards depend on the failing call still being measured (the
elapsed_ms is exactly the cost of the timeout, which is what you want
to chart).

### What's deferred from plan's Phase 7

- **Cached profiled DTOs** (`audience_payload_json` column): blocked by
  Phase 2 (alembic migration to add the column) and Phase 5 (audience
  profiles to know what to cache).
- **Locust / k6 baseline harness**: requires running infrastructure,
  better as a separate ops task than an interactive code change.

---

## 7b. Contract versioning — Phase 6 architecture

Phase 6 introduces a wire-level signal so an older Flutter binary can
detect that it is talking to a backend on a different version of this
contract. Two pieces work together:

### Backend: `X-Risk-Contract-Version` middleware

`backend/app/main.py` registers a `RiskContractVersionMiddleware` that
injects `X-Risk-Contract-Version: <RISK_CONTRACT_VERSION>` on every
response whose path matches `RISK_CONTRACT_ROUTE_PREFIXES` in
`backend/app/core/risk_contract.py`.

The route surface is intentionally narrow:

- `/mobile/analysis/risk-reports`
- `/mobile/analysis/risk-reports/{report_id}`
- `/mobile/analysis/risk-history`
- `/mobile/metrics/health-report`

Off-surface routes (auth, notifications, vitals ingestion, sleep) do
**not** receive the header. The version describes the **mobile risk
DTO contract** only — bumping it in lockstep with unrelated APIs would
be a category error.

The CORS middleware is configured with `expose_headers` so browser
clients (the Swagger UI on `/mobile-docs` and any future web SDK) can
read the header in JS contexts.

### Mobile: `RiskContractVersion` singleton

`lib/core/network/risk_contract_version.dart` defines the singleton
the Flutter `ApiClient` consults on every response:

- `expectedVersion` — the version this binary was compiled against
  (currently `0.4.0`).
- `latestObserved` — the most recent version the backend reported, or
  `null` if no risk-surface request has been made yet (useful when
  building a "Backend is ahead of your app" banner in Phase 8 UX).
- `inspect(headers)` — extracts `x-risk-contract-version` (lowercased
  per the `http` package convention), updates `latestObserved`, and
  emits a `debugPrint` warning **once per distinct mismatched value**
  so a stale binary chatting with a newer backend leaves a clear
  breadcrumb without spamming the device log.

Inspection is wired in `ApiClient._sendJsonRequest` so it runs on every
response (success or failure). Routes that omit the header are no-ops.

### Bumping rules

Patch / minor / major rules are documented at the top of
`backend/app/core/risk_contract.py`. The four files that must move
together when bumping are:

1. `backend/app/core/risk_contract.py` — `RISK_CONTRACT_VERSION`.
2. `lib/core/network/risk_contract_version.dart` — `_defaultExpectedVersion`.
3. `backend/docs/risk-contract-baseline.md` — top-of-file Wire version
   row + a new entry in the [Version history](#version-history).
4. `backend/tests/contract/test_mobile_risk_dto_snapshot.py` — only if
   the wire shape genuinely changed (a major bump).

A patch bump (internal refactor, no observable change) only requires
files 1, 2, 3.

---

## 8. Update procedure

When the contract genuinely evolves:

1. Edit `backend/app/schemas/monitoring.py`.
2. Update producer code in `backend/app/services/monitoring_service.py`.
3. Update the matching `EXPECTED_*_KEYS` in the snapshot test.
4. Run `pytest backend/tests/contract` and confirm the snapshot diff matches
   the intended change (no incidental drift).
5. Update the relevant section of this file **and** bump the
   `Baseline version` cell in the header.
6. If the change is breaking for older Flutter binaries, also bump
   `X-Risk-Contract-Version` (planned in Phase 6).

---

## 9. Verification commands

```bash
cd backend
python -m pytest tests/contract tests/test_risk_report_builder.py \
                 tests/test_risk_persistence_adapter.py \
                 tests/test_risk_alert_service_helpers.py \
                 tests/test_shap_explanation_contract.py -v --tb=short
```

Expected output (`v0.5`): **all green**, 0 failing.

Contract layer — DTO snapshot (`tests/contract/test_mobile_risk_dto_snapshot.py`):

- 9 snapshot tests pin the JSON keys of every mobile DTO (drift triggers a
  `Mobile contract drift detected on ...` failure with the exact set of
  added / removed keys).
- 3 round-trip tests catch silent drift caused by `model_config` changes.
- 7 invariant tests assert every deprecated alias mirrors its canonical
  source so removing it later cannot lose data.

Contract layer — versioning + OpenAPI (`tests/contract/test_mobile_risk_versioning.py`, Phase 6):

- 2 route-signature tests pin every risk path's `response_model`.
- 5 header tests prove `X-Risk-Contract-Version` is set on the risk
  surface and equals `RISK_CONTRACT_VERSION`.
- 13 scope tests prove `applies_to_path` recognises the risk surface and
  excludes auth / notifications / sleep / docs.
- 3 OpenAPI tests pin the path list and DTO component names exposed for
  mobile codegen.

Builder layer (`tests/test_risk_report_builder.py`):

- 5 `build_risk_report` tests
- 7 `build_risk_report_detail` tests
- 4 `build_risk_history_item` tests
- 3 cross-cutting builder invariant tests

Adapter layer (Phase 3b):

- `tests/test_risk_persistence_adapter.py` — 7 tests pinning
  `build_features_json` shape, value mirroring and `Decimal` encoding.
- `tests/test_risk_alert_service_helpers.py` — 5 helpers covered via
  module-level aliases pointing to `ModelApiHealthAdapter` static methods.
- `tests/test_shap_explanation_contract.py` — `_default_recommendations`
  and `_build_ai_explanation_payload` covered via the same alias pattern.

Full non-e2e backend suite (smoke):

```bash
python -m pytest tests/ \
  --ignore=tests/test_e2e_analysis_risk_read_surfaces.py \
  --ignore=tests/test_e2e_manual_sos.py \
  --ignore=tests/test_e2e_model_api_shap_persistence.py \
  --ignore=tests/test_e2e_relationships_real_db.py \
  --ignore=tests/test_e2e_risk_notification.py \
  --ignore=tests/test_e2e_risk_response_real_db.py \
  --ignore=tests/test_e2e_telemetry_real_db.py
```

Expected: 515 passed, 2 skipped (was 502 before Phase 4A slice 3b's 13 added risk-type filter tests).

Mobile parser smoke (after Phase 6):

```bash
flutter test test/features/analysis/repositories/risk_analysis_repository_test.dart \
             test/core/network/risk_contract_version_test.dart
```

Expected: 8 + 5 = 13 tests pass (mobile inspector now expects `0.5.0` after Phase 5's wire-version bump). Phase 4B slice 2c-mobile + 2d-mobile add 28 more Flutter tests (`flutter test test/features/fall/ test/core/notifications/fall_event_handler_test.dart`) covering the fall feature module + the FCM push handler. Phase 4A slice 3b-mobile adds 15 more Flutter tests (`flutter test test/features/analysis/risk_type_filter_chips_test.dart test/features/analysis/risk_history_provider_filter_test.dart`) covering the chip widget + provider state machine. Phase 8 slice 4a adds 21 more Flutter tests (`flutter test test/features/profile/`) covering the clinician audience provider + settings screen.
