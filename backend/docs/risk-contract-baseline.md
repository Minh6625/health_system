# Risk Contract Baseline — Phase 0

> Frozen snapshot of the **mobile-facing risk DTOs** produced by the backend
> before the Phase 1 cleanup begins. Treat this file as the source of truth
> the Flutter app is currently parsing in production.

| Field | Value |
| --- | --- |
| Baseline version | `v0.0` (pre-cleanup) |
| Captured from branch | `refactor/risk-core-phase0-audit` |
| Schema source | `backend/app/schemas/monitoring.py` |
| Snapshot test | `backend/tests/contract/test_mobile_risk_dto_snapshot.py` |
| Risk plan | `.windsurf/plans/risk-core-architecture-refactor-9ea607.md` |

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
| `risk_score` | `float` | **Duplicate of `score`.** Phase 1 candidate to drop. |
| `score` | `float` | Canonical risk value (0..100). |
| `health_score` | `float` | `100 - score`. UI surfaces this as the "good news" framing. |
| `risk_level` | `string` | `low` \| `medium` \| `high` \| `critical`. |
| `health_level` | `string \| null` | Optional UI tag (`good`, `watch`, …). **Phase 1 candidate to drop** — overlaps with `display_status`. |
| `display_status` | `string` | Localized label rendered on the dashboard chip. |
| `summary` | `string` | One-line Vietnamese narrative. |
| `timestamp` | `datetime` | ISO-8601 UTC. |
| `previous_score` | `float \| null` | Score of the immediately prior report. |
| `trend_7d` | `int[]` | Up to 7 daily samples used by the dashboard sparkline. |
| `key_features` | `string[]` | **Derivable from `top_factors[].key`.** Phase 1 candidate to drop. |
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
| `xai_explanation` | `string` | **Duplicate of `explanation`.** Phase 1 candidate to drop. |
| `features` | `dict[str, any]` | Raw feature values fed into the model. |
| `feature_importance` | `dict[str, float]` | **Subset of `breakdown[*].contribution_score`.** Phase 1 candidate to drop. |
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

## 6. Phase 1 cleanup candidates

Captured here so Phase 1 has an explicit checklist instead of re-deriving it
from the schema. Each candidate must:

1. Update the schema in `backend/app/schemas/monitoring.py`.
2. Update the producer in `backend/app/services/monitoring_service.py`.
3. Update the matching `EXPECTED_*_KEYS` set in
   `backend/tests/contract/test_mobile_risk_dto_snapshot.py`.
4. Update the matching mobile parser
   (`lib/features/analysis/repositories/risk_analysis_repository.dart` and
   the analysis DTOs).
5. Bump the **Baseline version** at the top of this file.

| Field | Owner DTO | Reason |
| --- | --- | --- |
| `risk_score` | `RiskReportResponse`, `RiskReportDetailResponse`, `RiskHistoryItemResponse` | Duplicate of `score`. Mobile already has fallback parsing. |
| `health_level` | `RiskReportResponse`, `RiskReportDetailResponse` | Overlaps with `display_status`. |
| `key_features` | `RiskReportResponse` | Derivable from `top_factors[].key`. |
| `xai_explanation` | `RiskReportDetailResponse` | Duplicate of `explanation`. |
| `feature_importance` | `RiskReportDetailResponse` | Subset of `breakdown[*].contribution_score`. |

> Removing duplicates is a breaking change for any binary still consuming
> only the duplicate field. Phase 6 introduces `X-Risk-Contract-Version` so
> the backend can dual-emit during a deprecation window before the duplicate
> keys are dropped here.

---

## 7. Update procedure

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

## 8. Verification command

```bash
cd backend
python -m pytest tests/contract -v --tb=short
```

Expected output: 12 tests passing, 0 failing, 0 warnings related to the
contract — drift triggers a `Mobile contract drift detected on ...` failure
with the exact set of added / removed keys.
