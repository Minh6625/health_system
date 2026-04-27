# UX Refactor — Phases Ledger (`refactor/ux-phase1-and-2`)

Tài liệu này tóm tắt mọi phase đã thực thi trên branch `refactor/ux-phase1-and-2`, bao gồm các quyết định **skip / blocked** và lý do, để tham chiếu khi review/merge.

> **Branch:** `refactor/ux-phase1-and-2`  
> **Last commit:** `50e7325` — phase17(W4) risk narrative copy  
> **Audit dimensions:** A=Honest UI, B=Battery/Network, C=Maintainability, D=Narrative Copy, E=Visual Theme

---

## A · Honest UI (lying-UI removal)

| ID | Commit | Scope |
|----|--------|-------|
| 1 | `23cb524` | Wire 4 dead emergency CTAs + fix sleep duration precedence |
| 2 | `1883e7d` | Sleep settings: replace dead toggles với "coming soon" disclosure |
| 3 | `19a66f4` | Replace mock alert history + wire health-score chevron |
| 4 | `3d4ced9` | Drop fake PIN + mock share button trên My Code tab |
| 5a | `e37cd95` | Wire unpair device tới real `DELETE /devices/{id}` |
| 5b | `fc4db1f` `98bf914` | Device connect: lock pair CTA + honest demo banner |
| 5c-A | `98bf914` | Confirm pair lock |
| 5d-A | `a39ab68` | Align device settings UI với backend schema (notify_high_hr, notify_low_spo2, notify_high_bp) |
| 6a | `356fd2d` | Plumb `calibration_data` vào DeviceModel + seed configure provider toggles |
| 6b | `c177c66` | Wire device name save qua `PATCH /devices/{id}` |
| 7 | `7fa46e9` | Vital-detail: drop dead "Xem xu hướng" TODO button (BE history endpoint không tồn tại) |

**Status:** ✅ Done.

---

## B · Battery / Network performance

| ID | Commit | Change |
|----|--------|--------|
| Phase 10 (W6) | `d146a22` | Throttle caregiver auto-refresh: FamilyDashboard 1s→15s, FamilyShell badge 2s→30s, EmergencySOSReceivedList 2s→10s. Realtime push remains primary delivery; timer là recovery fallback. |

**Status:** ✅ Done. Tests pin `autoRefreshInterval` defaults.

---

## C · Maintainability (large file splits)

| ID | Commit | Change |
|----|--------|--------|
| Phase 11 (W9) | `926de7e` | Drop 2 orphan emergency screens không reference |
| Phase 12 (W9) | `bbdada1` | Fence mock-scenarios debug menu với `kDebugMode && DeviceMockConfig.useMockData` |
| Phase 13 (W6) | `367d102` | Split `EmergencySOSDetailScreen` 1054→390 lines: 6 widgets + helpers |
| Phase 14 (W8) | `5941fc9` | Simplify `AuthPagesScreen` 143→81 lines: extract page indicator + CTA widgets, giữ PageView |
| Phase 17 (notif) | `77fcb41` | Split `NotificationsScreen` 2004 lines into 12 focused files |
| Phase 15 (W2) | `643bad9` `ca371a6` | Fold home dashboard 9 loose blocks into 3 visual zones (A/B/C) — **already-resolved** trước khi audit hiện tại bắt đầu |

**Status:** ✅ Done. All splits ship với tests pinning extracted widgets.

---

## D · Narrative copy (Risk cluster)

| ID | Commit | Change |
|----|--------|--------|
| Phase 17 (W4) | `50e7325` | Refine `dashboardRiskSummary` (4 cases) + stale fallback + hero card delta caption + risk report empty state + provider `emptyMessage`. Tone: actionable + warmer. |

**Strings updated** (xem code change for exact mapping):
- `dashboardRiskSummary('low')` — kèm "Tiếp tục duy trì thói quen hiện tại"
- `dashboardRiskSummary('medium')` — kèm action "nghỉ ngơi và đo lại sau ít giờ"
- `dashboardRiskSummary('critical')` — kèm escalation "liên hệ bác sĩ nếu thấy bất thường"
- `dashboardRiskSummary(default)` — "Đang chờ dữ liệu mới từ thiết bị của bạn"
- Stale fallback ngắn gọn + chỉ rõ next action
- Hero & detail cards: "Chưa có lần đo trước để so sánh" (tự nhiên hơn)
- Risk report empty: hint user đeo thiết bị thêm vài giờ

**Status:** ✅ Done. 14 dashboard helper tests + 15 analysis tests pass.

---

## E · Visual theme (Sleep cluster)

**Phase 18 (W7) — SKIPPED, decision documented.**

Audit recommendation: "default light to match rest of app".

**Decision: keep dark theme** vì:
1. Sleep cluster có **intentional thematic design** — `StarryBackground` widget, navy gradient (`#101C2F` → `#071220`), cyan `#48D6FF` accent, gold star highlights. Đây là "night/sleep semantic" giống Apple Health, Fitbit, Whoop.
2. Refactor sang light = redesign 10+ widgets (`sleep_hero_card`, `sleep_trend_chart`, `sleep_timeline_bar`, `phase_composition_chart`, `info_tooltip_icon`, `shimmer_sleep_loading`, `no_data_tonight_view`, `_DateLoadingShimmer`, `_DateErrorBanner`, `_ErrorView`) + new color tokens + visual rebuild. ~4-6h work + risk phá visual identity feature.
3. Audit khuyến nghị mang tính chủ quan; nhiều health apps cố tình dùng dark cho sleep vì associate với "night".

**Alternative cho future work** nếu cần consistency: scoped accessible high-contrast tokens trong dark palette (text >= AA 4.5:1, error banner foreground softer).

**Status:** ⏭ Skipped — documented.

---

## Phase 16 (W3) — VitalDetail history — BLOCKED

**Backend không expose endpoint vital-signs history.** Confirmed via `backend/app/api/routes/monitoring.py`:
- `GET /metrics/vital-signs/latest` ✅
- `GET /metrics/sleep/history` ✅ (sleep-specific)
- `GET /analysis/risk-history` ✅ (risk-specific)
- `GET /metrics/vital-signs/history` ❌ **does not exist**

Decision: Dead "Xem xu hướng" CTA đã removed ở Phase 7 (`7fa46e9`). Mini chart dưới hero shows 24h trend đủ context. Comment tại `vital_detail_screen.dart:154-160` ghi rõ rationale.

**Status:** ⏭ Blocked → resolved-via-removal.

---

## Test coverage summary

| Suite | Status |
|-------|--------|
| `test/features/home/presentation/screens/home_dashboard_screen_test.dart` | 14 pass |
| `test/features/analysis/**` | 15 pass |
| `test/features/family/screens/family_dashboard_screen_test.dart` | autoRefreshInterval pinned |
| `test/features/emergency/screens/emergency_sos_received_list_screen_test.dart` | autoRefreshInterval pinned |
| `test/features/family/screens/family_shell_flow_test.dart` | badgeRefreshInterval pinned |
| `test/features/emergency/widgets/sos_detail_widgets_test.dart` | 17 unit tests cho extracted SOS widgets |
| `test/features/auth/widgets/auth_pages_widgets_test.dart` | indicator + CTA widget tests |

---

## Manual device test checklist (anh review)

### Home dashboard
- [ ] Risk summary copy hiển thị mới (low/medium/critical) — đảm bảo wording mới
- [ ] Stale fallback "Dữ liệu đã cũ. Hãy đồng bộ thiết bị..."
- [ ] 3 zones A/B/C visual rõ ràng

### Risk cluster
- [ ] `RiskScoreHeroCard` hiển thị "Chưa có lần đo trước để so sánh" khi previous score null
- [ ] Empty state risk report hiển thị guidance đeo thiết bị thêm

### Vital detail
- [ ] Không còn nút "Xem xu hướng" (đã removed)
- [ ] Mini chart 24h render bình thường
- [ ] 5-zone safe-range gauge + collapsible education card

### Device flow
- [ ] Pair device CTA enabled chỉ khi prerequisites OK + honest demo banner mọi step
- [ ] Notification toggles seed đúng từ backend `calibration_data`
- [ ] Save device name → PATCH endpoint thật, không fake success
- [ ] Unpair → DELETE endpoint thật, list refresh

### Caregiver / Family
- [ ] FamilyDashboard không spam network (refresh ~15s)
- [ ] Tab badge update sau ~30s (hoặc khi push event)
- [ ] EmergencySOSReceivedList realtime push primary, timer ~10s fallback

### Emergency SOS
- [ ] Detail screen render đầy đủ với extracted widgets — không regression visual
- [ ] Confidence hiển thị 0-100%, trigger reason surface đúng
- [ ] Timeline parse `time_offset` / `event` keys (no crash)

### Auth
- [ ] Auth pages: indicator + "Bắt đầu ngay" CTA hoạt động đúng
- [ ] Register screen không hiển thị duplicate confirm-password error

### Debug menu
- [ ] Build release: device debug menu **không xuất hiện** (kDebugMode gate)
- [ ] Build debug + DeviceMockConfig.useMockData = true: menu xuất hiện

### Sleep
- [ ] Dark theme giữ nguyên (intentional — không refactor sang light)
- [ ] Sleep settings "coming soon" toggles disabled rõ ràng

---

## Open follow-ups (post-merge)

1. **Sleep theme accessibility audit** — nếu user muốn align: scoped contrast tokens trong dark palette (Phase 18 alternative).
2. **Vital-signs history endpoint** — BE feature request để revive history CTA tại vital detail.
3. **AGENTS.md GitNexus impact** — adopt impact analysis pre-edit cho subsequent refactors theo project rules.
