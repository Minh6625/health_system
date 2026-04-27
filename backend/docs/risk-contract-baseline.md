# Risk Contract Baseline

> Source of truth for the **mobile-facing risk DTOs** produced by the backend
> and consumed by the Flutter app. Always reflects the contract at the
> baseline version listed below. Each Phase update bumps the version and
> appends an entry to the [Version history](#version-history) table.

| Field | Value |
| --- | --- |
| Baseline version | `v0.3` (Phase 3a — typed normalized risk row) |
| Captured from branch | `refactor/risk-core-phase3-typed-normalized-row` |
| Schema source | `backend/app/schemas/monitoring.py` |
| Normalized row | `backend/app/services/normalized_risk_row.py` |
| DTO builder | `backend/app/services/risk_report_builder.py` |
| Snapshot test | `backend/tests/contract/test_mobile_risk_dto_snapshot.py` |
| Builder unit test | `backend/tests/test_risk_report_builder.py` |
| Mobile parser | `lib/features/analysis/repositories/risk_analysis_repository.dart` |
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

## 7. DTO builders + typed normalized row — Phase 3a architecture

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

### Phase 3b follow-up — adapter extraction (not yet done)

The plan's full Phase 3 also extracts adapters out of
`risk_alert_service.py`:

- `ModelApiHealthAdapter` — `to_record(payload) -> dict`,
  `from_response(resp) -> NormalizedRiskRow`-shaped object.
- `RiskPersistenceAdapter` — `to_db_row(NormalizedExplanation) -> RiskExplanation`.
- `MobileRiskDtoAdapter` — already exists as `risk_report_builder.py`.

The typed `NormalizedRiskRow` lands first because the adapters will
produce / consume it. Phase 3b will live on a separate branch and bring
`risk_alert_service.calculate_device_risk` from ~250 LOC to <100 LOC.

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
python -m pytest tests/contract tests/test_risk_report_builder.py -v --tb=short
```

Expected output (`v0.3`): **38 tests passing**, 0 failing.

Contract layer (`tests/contract/test_mobile_risk_dto_snapshot.py`):

- 9 snapshot tests pin the JSON keys of every mobile DTO (drift triggers a
  `Mobile contract drift detected on ...` failure with the exact set of
  added / removed keys).
- 3 round-trip tests catch silent drift caused by `model_config` changes.
- 7 invariant tests assert every deprecated alias mirrors its canonical
  source so Phase 6 removal cannot lose data.

Builder layer (`tests/test_risk_report_builder.py`):

- 5 `build_risk_report` tests
- 7 `build_risk_report_detail` tests
- 4 `build_risk_history_item` tests
- 3 cross-cutting builder invariant tests
