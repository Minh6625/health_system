# Full E2E Coverage Matrix — health_system

## 1. Mục tiêu tài liệu
Tài liệu này tổng hợp toàn bộ bức tranh E2E của app hiện tại, bao gồm:
- module / submodule chính của mobile app;
- flow user-facing cần chứng minh trước khi ship;
- backend routes/services/data path liên quan;
- test evidence hiện có;
- khoảng trống, mock/stub còn sót;
- mức sẵn sàng ship E2E.

Tài liệu được dựng từ các nguồn chính:
- [`README.md`](README.md)
- [`lib/core/routes/app_router.dart`](lib/core/routes/app_router.dart)
- các feature trong `lib/features/`
- các route trong `backend/app/api/routes/`
- plans hiện có trong `plans/health_score/`, `plans/sleep/`, [`plans/E2E/emergency-release-checklist.md`](plans/E2E/emergency-release-checklist.md)
- test backend trong `backend/tests/`
- test Flutter trong `test/features/`
- nhật ký triển khai trong [`progress.md`](progress.md) và phát hiện nghiên cứu trong [`findings.md`](findings.md)

---

## 2. Định nghĩa “ship E2E” cho repo này
Một module chỉ nên được xem là ship E2E khi đạt đủ các lớp sau:

| Lớp | Yêu cầu |
|---|---|
| Contract | API contract ổn định, semantics không mâu thuẫn giữa backend và mobile |
| Backend evidence | Có test hoặc verify đủ mạnh cho DB/API/pipeline thực hoặc tương đương rất sát production |
| Mobile evidence | Có flow test hoặc evidence user-facing không còn dựa mock trong đường nóng |
| Release path | Có thể mô tả ít nhất một hành trình người dùng hoàn chỉnh từ đầu đến cuối |

### Thang trạng thái
| Trạng thái | Ý nghĩa |
|---|---|
| `READY` | Đủ evidence để đưa vào release scope E2E |
| `PARTIAL` | Đã có bằng chứng một phần nhưng chưa đủ để chốt ship |
| `NOT_READY` | Chưa có coverage/E2E đáng tin cậy |
| `BLOCKED_BY_MOCK` | Flow chính còn bị chặn bởi mock/stub/demo provider |

---

## 3. Toàn cảnh coverage theo domain

| Domain | Trạng thái | Lý do chính |
|---|---|---|
| Auth | `PARTIAL` | Có backend service tests + Flutter provider/widget tests, nhưng chưa có API/mobile flow E2E hoàn chỉnh |
| Home Dashboard | `PARTIAL` | Health score semantics đã nối backend thật, nhưng mới có focused verification; chưa có full user journey E2E |
| Analysis / Risk report / History | `PARTIAL` | Đã bỏ mock provider và có repo-backed flow, nhưng thiếu full cross-screen E2E evidence |
| Sleep Analysis | `READY` gần mức ship | Có real backend/live DB E2E + Flutter repository/provider/widget-flow tests + linked-profile path |
| Emergency Manual SOS | `PARTIAL` | Có route/backend surface và screen tests, nhưng thiếu hành trình E2E đầy đủ từ trigger → list/detail/resolve |
| Emergency Risk Escalation / Critical Overlay | `PARTIAL` | Có backend live E2E mạnh cho risk notification pipeline và focused mobile verification, nhưng checklist plan chưa đóng hoàn toàn |
| Notifications | `PARTIAL` | Có helper tests và phụ thuộc risk flow, nhưng chưa có inbox/detail/read/open E2E độc lập |
| Family / Relationships | `BLOCKED_BY_MOCK` | Shell và nhiều flow vẫn dựa [`SharedFamilyMockProvider`](lib/features/family/providers/shared_family_mock_provider.dart:8) |
| Device | `BLOCKED_BY_MOCK` | Pairing/BLE discovery/status detail vẫn còn mock/demo path trong [`device_mock_data.dart`](lib/features/device/mock/device_mock_data.dart:3) |
| Health Monitoring / Vital detail | `BLOCKED_BY_MOCK` | Vital detail route vẫn bọc [`VitalDetailMockProvider`](lib/features/health_monitoring/providers/vital_detail_mock_provider.dart:12) tại router |
| Profile | `NOT_READY` | Có route và màn hình nhưng chưa thấy evidence E2E/user-flow coverage |
| Settings | `NOT_READY` | Có backend settings route nhưng chưa có coverage E2E/mobile flow |
| Admin surfaces | `NOT_READY` | Có route backend nhưng không có dấu vết app-flow E2E hiện tại |

---

## 4. Ma trận chi tiết theo module

## 4.1 Auth

### User-facing flows cần E2E
- Start → register → verify email
- login → dashboard
- forgot password → verify OTP → reset password
- bootstrap session / persistent login khi mở app lại
- logout
- refresh token khi access token hết hạn

### Surface liên quan
- Mobile screens: [`AuthPagesScreen`](lib/features/auth/screens/auth_pages_screen.dart:7), [`LoginScreen`](lib/features/auth/screens/login_screen.dart:13), [`RegisterScreen`](lib/features/auth/screens/register_screen.dart:12), [`EmailVerificationScreen`](lib/features/auth/screens/email_verification_screen.dart:13), [`ForgotPasswordScreen`](lib/features/auth/screens/forgot_password_screen.dart:11), [`ResetOtpVerificationScreen`](lib/features/auth/screens/reset_otp_verification_screen.dart:15), [`ResetPasswordScreen`](lib/features/auth/screens/reset_password_screen.dart:13), [`ChangePasswordScreen`](lib/features/auth/screens/change_password_screen.dart:10)
- Provider/repository: [`AuthProvider`](lib/features/auth/providers/auth_provider.dart:8), [`AuthRepository`](lib/features/auth/repositories/auth_repository.dart:5)
- Backend routes: [`register()`](backend/app/api/routes/auth.py:46), [`verify_email()`](backend/app/api/routes/auth.py:99), [`resend_verification()`](backend/app/api/routes/auth.py:114), [`login()`](backend/app/api/routes/auth.py:150), [`refresh_token()`](backend/app/api/routes/auth.py:189), [`forgot_password()`](backend/app/api/routes/auth.py:212), [`verify_reset_otp()`](backend/app/api/routes/auth.py:247), [`reset_password()`](backend/app/api/routes/auth.py:262), [`change_password()`](backend/app/api/routes/auth.py:277)

### Coverage hiện có
- Backend service/unit: [`backend/tests/test_auth_service.py`](backend/tests/test_auth_service.py), [`backend/tests/test_auth_schema.py`](backend/tests/test_auth_schema.py), [`backend/tests/test_auth_age_validation.py`](backend/tests/test_auth_age_validation.py)
- Flutter provider/widget: [`test/features/auth/providers/auth_provider_test.dart`](test/features/auth/providers/auth_provider_test.dart), [`test/features/auth/screens/register_screen_test.dart`](test/features/auth/screens/register_screen_test.dart)
- Persistent login logic được verify ở [`AuthProvider.bootstrapSession`](test/features/auth/providers/auth_provider_test.dart:257)

### Gaps
- Chưa có backend HTTP/API integration test cho auth endpoints.
- Chưa có mobile flow test nối nhiều màn register/login/reset theo route thực.
- Chưa có E2E chứng minh login thật rồi vào [`HomeDashboardScreen`](lib/features/home/presentation/screens/home_dashboard_screen.dart:151).
- README test backend còn cho thấy auth API integration là future/TODO ở [`backend/tests/README.md`](backend/tests/README.md).

### Trạng thái
`PARTIAL`

### Để đạt ship E2E
- Thêm backend API integration cho register/login/refresh/reset.
- Thêm mobile flow test tối thiểu cho login happy path và persistent login restore.
- Thêm một release-path end-to-end: login → dashboard → logout.

---

## 4.2 Home Dashboard / Health Score

### User-facing flows cần E2E
- Mở dashboard thấy health score, trạng thái thiết bị, sleep preview, vitals preview
- Từ dashboard điều hướng sang risk analysis, sleep, notification, vital detail
- Self profile và linked-profile rendering nhất quán

### Surface liên quan
- Mobile: [`HomeDashboardScreen`](lib/features/home/presentation/screens/home_dashboard_screen.dart:151), [`HomeDashboardProvider`](lib/features/home/presentation/providers/home_dashboard_provider.dart:9), [`HomeDashboardRepository`](lib/features/home/repositories/home_dashboard_repository.dart:112)
- Backend: monitoring/risk read models qua [`backend/app/api/routes/monitoring.py`](backend/app/api/routes/monitoring.py), [`backend/app/api/routes/risk.py`](backend/app/api/routes/risk.py)
- Kế hoạch: [`plans/health_score/README.md`](plans/health_score/README.md)

### Coverage hiện có
- Focused Flutter helper tests: [`test/features/home/presentation/screens/home_dashboard_screen_test.dart`](test/features/home/presentation/screens/home_dashboard_screen_test.dart)
- Focused backend verification và semantics evidence trong [`progress.md`](progress.md)
- Health semantics + contract findings trong [`findings.md`](findings.md)

### Gaps
- Chưa có full dashboard widget-flow E2E từ auth vào dashboard rồi drill-down qua các màn con.
- Dashboard vẫn phụ thuộc các module con chưa hoàn toàn READY như notifications, vital detail, family.
- Chưa có explicit linked-profile dashboard E2E matrix hoàn chỉnh ngoài các nhánh lẻ của health/sleep.

### Trạng thái
`PARTIAL`

### Để đạt ship E2E
- Một end-to-end route test: login → dashboard → risk report → risk detail → history.
- Một linked-profile dashboard verification path.
- Loại bỏ hoặc đóng gap ở các CTA đang dẫn đến module mock/not-ready.

---

## 4.3 Analysis / Risk Report / Risk History

### User-facing flows cần E2E
- Mở risk report latest
- Xem detail của một report
- Xem history và pagination/range
- Linked profile dùng cùng contract

### Surface liên quan
- Mobile: [`RiskReportScreen`](lib/features/analysis/presentation/screens/risk_report_screen.dart:17), [`RiskReportDetailScreen`](lib/features/analysis/presentation/screens/risk_report_detail_screen.dart:17), [`RiskHistoryScreen`](lib/features/analysis/presentation/screens/risk_history_screen.dart:17), [`RiskReportProvider`](lib/features/analysis/providers/risk_report_provider.dart:6), [`RiskHistoryProvider`](lib/features/analysis/providers/risk_history_provider.dart:5), [`RiskAnalysisRepository`](lib/features/analysis/repositories/risk_analysis_repository.dart:6)
- Backend routes canonical: [`list_risk_reports()`](backend/app/api/routes/monitoring.py:80), [`get_risk_report_detail()`](backend/app/api/routes/monitoring.py:97), [`get_risk_history()`](backend/app/api/routes/monitoring.py:117)
- Monitoring read service evidence: [`backend/tests/test_monitoring_service_contract.py`](backend/tests/test_monitoring_service_contract.py)

### Coverage hiện có
- Flutter provider tests: [`test/features/analysis/providers/risk_report_provider_test.dart`](test/features/analysis/providers/risk_report_provider_test.dart), [`test/features/analysis/providers/risk_history_provider_test.dart`](test/features/analysis/providers/risk_history_provider_test.dart)
- Flutter repository tests: [`test/features/analysis/repositories/risk_analysis_repository_test.dart`](test/features/analysis/repositories/risk_analysis_repository_test.dart)
- Flutter screen-flow tests: [`test/features/analysis/presentation/screens/risk_flow_test.dart`](test/features/analysis/presentation/screens/risk_flow_test.dart)
- Backend contract verification: [`backend/tests/test_monitoring_service_contract.py`](backend/tests/test_monitoring_service_contract.py)
- Backend HTTP canonical route verification: [`backend/tests/test_monitoring_routes_http.py`](backend/tests/test_monitoring_routes_http.py)
- Backend live DB E2E: [`backend/tests/test_e2e_analysis_risk_read_surfaces.py`](backend/tests/test_e2e_analysis_risk_read_surfaces.py)

### Gaps
- Chưa có Flutter screen-flow test xuyên các màn risk report/detail/history.
- Chưa có backend live DB E2E riêng cho report/detail/history read surfaces.
- Chưa có proof đầy đủ cho linked-profile path ở analysis ngoài contract/provider level.

### Trạng thái
`PARTIAL`

### Để đạt ship E2E
- Thêm widget-flow/route-flow test cho risk report → detail → history.
- Thêm backend HTTP E2E cho latest/detail/history với auth + `X-Target-Profile-Id`.
- Chốt matrix no-data/stale-data/critical-data ở analysis flow.

---

## 4.4 Sleep Analysis

### User-facing flows cần E2E
- ingest sleep session → DB → latest report → history → detail
- self profile
- linked profile qua `X-Target-Profile-Id`
- settings/local UX không phá core flow
- no-data / before-6AM rule / canonical `sleep_date`

### Surface liên quan
- Mobile: [`SleepReportScreen`](lib/features/sleep_analysis/screens/sleep_report_screen.dart:14), [`SleepDetailScreen`](lib/features/sleep_analysis/screens/sleep_detail_screen.dart:12), [`SleepHistoryScreen`](lib/features/sleep_analysis/screens/sleep_history_screen.dart:9), [`SleepSettingsScreen`](lib/features/sleep_analysis/screens/sleep_settings_screen.dart:5), [`SleepProvider`](lib/features/sleep_analysis/providers/sleep_provider.dart:9), [`SleepRepositoryImpl`](lib/features/sleep_analysis/repositories/sleep_repository.dart:26)
- Backend routes: [`ingest_sleep_session()`](backend/app/api/routes/telemetry.py:404) và monitoring sleep endpoints trong [`backend/app/api/routes/monitoring.py`](backend/app/api/routes/monitoring.py)
- Plan: [`plans/sleep/README.md`](plans/sleep/README.md)

### Coverage hiện có
- Live DB/backend E2E: [`backend/tests/test_e2e_telemetry_real_db.py`](backend/tests/test_e2e_telemetry_real_db.py)
- Backend contract/unit: [`backend/tests/test_monitoring_service_contract.py`](backend/tests/test_monitoring_service_contract.py)
- Flutter repository tests: [`test/features/sleep_analysis/repositories/sleep_repository_test.dart`](test/features/sleep_analysis/repositories/sleep_repository_test.dart)
- Flutter provider tests: [`test/features/sleep_analysis/providers/sleep_provider_test.dart`](test/features/sleep_analysis/providers/sleep_provider_test.dart)
- Flutter widget/screen flow: [`test/features/sleep_analysis/widgets/sleep_widgets_test.dart`](test/features/sleep_analysis/widgets/sleep_widgets_test.dart), [`test/features/sleep_analysis/screens/sleep_flow_test.dart`](test/features/sleep_analysis/screens/sleep_flow_test.dart)
- Progress evidence: [`progress.md`](progress.md)

### Gaps
- Chưa có `integration_test/` chạy trên thiết bị thật; hiện là hybrid E2E (backend real + Flutter widget-flow).
- AI summary phase vẫn được xem là optional enrichment theo [`plans/sleep/README.md`](plans/sleep/README.md), nên không phải blocker cho core flow.

### Trạng thái
`READY`

### Để giữ trạng thái READY khi ship
- Re-run live DB E2E với gate `RUN_REAL_DB_E2E=1` trước release.
- Đảm bảo Home preview sleep và Sleep screens dùng cùng semantics `sleep_date`.
- Nếu thêm linked caregiver scenarios mới, mở rộng matrix tests thay vì fallback về mock.

---

## 4.5 Emergency — Manual SOS

### User-facing flows cần E2E
- User kích hoạt manual SOS
- SOS persisted / caregiver nhận được alert
- Xem danh sách SOS caregiver
- Mở detail SOS
- Resolve SOS
- Confirm screen hiển thị đúng mode manual/risk escalation

### Surface liên quan
- Mobile: [`ManualSOSScreen`](lib/features/emergency/screens/manual_sos_screen.dart:11), [`SosConfirmScreen`](lib/features/emergency/screens/sos_confirm_screen.dart:11), [`EmergencySOSDetailScreen`](lib/features/emergency/screens/emergency_sos_detail_screen.dart:17), [`EmergencySOSReceivedListScreen`](lib/features/emergency/screens/emergency_sos_received_list_screen.dart:14)
- Backend routes: [`trigger_sos()`](backend/app/api/routes/emergency.py:19), [`get_sos_alerts()`](backend/app/api/routes/emergency.py:41), [`get_sos_detail()`](backend/app/api/routes/emergency.py:61), [`resolve_sos()`](backend/app/api/routes/emergency.py:96)

### Coverage hiện có
- UI copy test: [`test/features/emergency/screens/sos_confirm_screen_test.dart`](test/features/emergency/screens/sos_confirm_screen_test.dart)
- Manual screen flow test: [`test/features/emergency/screens/manual_sos_screen_test.dart`](test/features/emergency/screens/manual_sos_screen_test.dart)
- Caregiver list/detail/resolve flow test: [`test/features/emergency/screens/emergency_sos_flow_test.dart`](test/features/emergency/screens/emergency_sos_flow_test.dart)
- Risk-response repository test có chạm emergency repo path gián tiếp: [`test/features/emergency/repositories/emergency_caregiver_repository_test.dart`](test/features/emergency/repositories/emergency_caregiver_repository_test.dart)
- Backend HTTP/API contract: [`backend/tests/test_emergency_routes_http.py`](backend/tests/test_emergency_routes_http.py), [`backend/tests/test_emergency_service_contract.py`](backend/tests/test_emergency_service_contract.py)
- Backend live DB E2E: [`backend/tests/test_e2e_manual_sos.py`](backend/tests/test_e2e_manual_sos.py)
- Device harness integration: [`integration_test/emergency_manual_sos_real_device_e2e_test.dart`](integration_test/emergency_manual_sos_real_device_e2e_test.dart)
- Fresh host verification log: [`progress.md`](progress.md)

### Gaps
- Focused Flutter, backend contract, và live-DB manual SOS evidence đã được refresh ngày April 21, 2026 trong [`progress.md`](progress.md), nhưng chưa có evidence pass trên thiết bị thật.
- Một thiết bị chưa đủ để chứng minh live caregiver push trên thiết bị thứ hai.
- Cần re-run device harness trên máy có `adb`/toolchain đầy đủ để chốt evidence mới nhất.

### Trạng thái
`PARTIAL`

### Để đạt ship E2E
- Backend API integration cho trigger/list/detail/resolve.
- Flutter flow test cho caregiver list/detail.
- Một end-to-end demo path có evidence gửi SOS thật hoặc simulated backend hợp lệ.

---

## 4.6 Emergency — Risk Escalation / Critical Overlay

### User-facing flows cần E2E
- telemetry/vitals bất thường → risk calculation
- alert tạo trong DB và push tới mobile
- app foreground/background/terminated xử lý push đúng
- critical risk mở fullscreen overlay/native takeover
- user chọn `safe` / `help_requested` / timeout escalation
- auth fallback khi token hết hạn

### Surface liên quan
- Backend routes: [`calculate_risk()`](backend/app/api/routes/risk.py:340), [`respond_to_risk_alert`](backend/app/api/routes/risk.py:314), telemetry bridge [`ingest_vitals()`](backend/app/api/routes/telemetry.py:160), [`ingest_alert()`](backend/app/api/routes/telemetry.py:285)
- Mobile: [`RiskAlertFullScreenOverlay`](lib/features/emergency/widgets/risk_alert_full_screen_overlay.dart:20), realtime service [`sos_realtime_alert_service.dart`](lib/features/emergency/services/sos_realtime_alert_service.dart), native Android bridge ở `android/app/src/main/.../MainActivity.kt`
- Release gate: [`plans/E2E/emergency-release-checklist.md`](plans/E2E/emergency-release-checklist.md)

### Coverage hiện có
- Backend live E2E: [`backend/tests/test_e2e_risk_notification.py`](backend/tests/test_e2e_risk_notification.py)
- Backend focused flows: [`backend/tests/test_risk_escalation_flow.py`](backend/tests/test_risk_escalation_flow.py), [`backend/tests/test_telemetry_risk_pipeline.py`](backend/tests/test_telemetry_risk_pipeline.py), [`backend/tests/test_e2e_risk_response_real_db.py`](backend/tests/test_e2e_risk_response_real_db.py)
- Flutter focused tests: [`test/features/emergency/services/sos_realtime_alert_service_helpers_test.dart`](test/features/emergency/services/sos_realtime_alert_service_helpers_test.dart), [`test/features/emergency/services/sos_realtime_alert_service_flow_test.dart`](test/features/emergency/services/sos_realtime_alert_service_flow_test.dart), [`test/features/emergency/widgets/risk_alert_full_screen_overlay_test.dart`](test/features/emergency/widgets/risk_alert_full_screen_overlay_test.dart), [`test/features/emergency/screens/sos_confirm_screen_test.dart`](test/features/emergency/screens/sos_confirm_screen_test.dart)
- Device harness integration: [`integration_test/emergency_risk_alert_real_device_e2e_test.dart`](integration_test/emergency_risk_alert_real_device_e2e_test.dart)
- Verification log trong [`progress.md`](progress.md)

### Gaps
- Focused Flutter, backend contract, và live-DB risk-response evidence đã được refresh ngày April 21, 2026, nhưng foreground/background/terminated trên thiết bị thật vẫn chưa có proof lưu cùng checklist.
- Cần chốt pass/fail thực tế cho stale-token refresh và refresh-fail replay trên thiết bị thật.
- Live DB risk-notification E2E vẫn còn partial vì DB hiện tại thiếu active device + recent vitals cho 2 case.
- Device harness hiện mới dừng ở mức code + harness trên branch; máy hiện tại còn thiếu toolchain Windows desktop và `adb` từ WSL để prove thêm.

### Trạng thái
`PARTIAL`

### Để đạt ship E2E
- Chốt matrix thiết bị thật cho foreground/background/terminated.
- Evidence rõ cho timeout escalation + auth recovery sau login.
- Gắn checklist release vào một tài liệu pass/fail duy nhất.

---

## 4.7 Notifications

### User-facing flows cần E2E
- fetch danh sách notifications
- mở detail notification
- mark as read
- nhận / đăng ký / huỷ push token
- open notification dẫn đúng màn đích

### Surface liên quan
- Mobile: [`NotificationsScreen`](lib/features/notifications/screens/notifications_screen.dart:53)
- Backend routes: [`get_notifications()`](backend/app/api/routes/notifications.py:25), [`get_notification_detail()`](backend/app/api/routes/notifications.py:49), [`mark_notification_as_read()`](backend/app/api/routes/notifications.py:65), [`upsert_push_token()`](backend/app/api/routes/notifications.py:86), [`unregister_push_token()`](backend/app/api/routes/notifications.py:105)

### Coverage hiện có
- Helper/severity tests: [`test/features/notifications/screens/notifications_screen_test.dart`](test/features/notifications/screens/notifications_screen_test.dart)
- Risk push open behavior được verify gián tiếp qua emergency realtime helper tests và progress log

### Gaps
- Chưa có repository/provider riêng với coverage end-to-end cho inbox/detail/read-state.
- Chưa có user-flow test cho notification list và deep-link/open target đầy đủ.
- Chưa có backend API integration riêng cho notification endpoints.

### Trạng thái
`PARTIAL`

### Để đạt ship E2E
- Tạo coverage cho inbox fetch/detail/read.
- Chứng minh open target tới risk/SOS/detail từ notification list và từ OS push.
- Kiểm tra push-token register/unregister trong lifecycle app thực.

---

## 4.8 Family / Relationships / Caregiver dashboard

### User-facing flows cần E2E
- xem dashboard người thân
- xem contact list
- tìm kiếm user / gửi request
- accept/reject request
- sửa permission / tag / unlink
- xem linked contact detail
- tab SOS của caregiver

### Surface liên quan
- Mobile shell: [`FamilyShellScreen`](lib/features/family/screens/family_shell_screen.dart:19)
- Providers/screens: [`SharedFamilyMockProvider`](lib/features/family/providers/shared_family_mock_provider.dart:8), [`FamilyDashboardProvider`](lib/features/family/providers/family_dashboard_provider.dart:7), [`LinkedContactDetailProvider`](lib/features/family/providers/linked_contact_detail_provider.dart:6), [`ContactListScreen`](lib/features/family/screens/contact_list_screen.dart:13), [`AddContactScreen`](lib/features/family/screens/add_contact_screen.dart:26), [`LinkedContactDetailScreen`](lib/features/family/screens/linked_contact_detail_screen.dart:15), [`FamilyDashboardScreen`](lib/features/family/screens/family_dashboard_screen.dart:19)
- Backend routes: [`relationships/dashboard`](backend/app/api/routes/relationships.py:21), [`relationships/{contact_id}/detail`](backend/app/api/routes/relationships.py:33), [`access-profiles`](backend/app/api/routes/relationships.py:46), [`relationships/search`](backend/app/api/routes/relationships.py:59), [`relationships`](backend/app/api/routes/relationships.py:72), [`relationships/request`](backend/app/api/routes/relationships.py:85), [`relationships/accept`](backend/app/api/routes/relationships.py:101), [`relationships/{relationship_id}`](backend/app/api/routes/relationships.py:120), delete route [`relationships/{relationship_id}`](backend/app/api/routes/relationships.py:139)

### Coverage hiện có
- Không thấy test Flutter cho family module trong `test/features/family/`.
- Chỉ có contract/linked-profile evidence gián tiếp ở sleep/risk flows.

### Blockers rõ ràng
- Shell vẫn dùng [`SharedFamilyMockProvider`](lib/features/family/screens/family_shell_screen.dart:50).
- Provider singleton này vẫn tổng hợp nhiều hành vi giả lập/mix optimistic UI ở [`SharedFamilyMockProvider`](lib/features/family/providers/shared_family_mock_provider.dart:8).
- Add contact flow còn comment/giá trị mock trong [`AddContactScreen`](lib/features/family/screens/add_contact_screen.dart:26).
- Mock contact snapshots còn tồn tại ở [`lib/features/family/mock/contact_mock_data.dart`](lib/features/family/mock/contact_mock_data.dart:3).

### Trạng thái
`BLOCKED_BY_MOCK`

### Để đạt ship E2E
- Thay shell/provider mock bằng provider/repository thật cho toàn bộ family flow.
- Thêm backend integration tests cho request/accept/update/remove/search.
- Thêm Flutter flow tests cho tabs dashboard/contact/detail/add-contact.
- Chốt linked-profile permission matrix dùng dữ liệu thật, không synthetic snapshot.

---

## 4.9 Device

### User-facing flows cần E2E
- xem danh sách devices
- xem detail/status
- scan/pair device
- configure settings
- update/delete device
- device status ảnh hưởng dashboard/monitoring

### Surface liên quan
- Screens/providers: [`DeviceScreen`](lib/features/device/screens/device_screen.dart:20), [`DeviceConnectScreen`](lib/features/device/screens/device_connect_screen.dart:13), [`DeviceConfigureScreen`](lib/features/device/screens/device_configure_screen.dart:14), [`DeviceStatusDetailScreen`](lib/features/device/screens/device_status_detail_screen.dart:16), [`DeviceProvider`](lib/features/device/providers/device_provider.dart:7), [`DeviceConnectProvider`](lib/features/device/providers/device_connect_provider.dart:17), [`DeviceStatusDetailProvider`](lib/features/device/providers/device_status_detail_provider.dart:20), [`DeviceRepository`](lib/features/device/repositories/device_repository.dart:4)
- Backend routes: [`get_devices()`](backend/app/api/routes/device.py:23), [`get_device()`](backend/app/api/routes/device.py:44), [`create_device()`](backend/app/api/routes/device.py:67), [`update_device()`](backend/app/api/routes/device.py:86), [`delete_device()`](backend/app/api/routes/device.py:113), [`scan_and_pair_device()`](backend/app/api/routes/device.py:132), [`update_device_settings()`](backend/app/api/routes/device.py:163)

### Coverage hiện có
- Không thấy test Flutter riêng cho device module trong `test/features/device/`.
- Không thấy backend integration/E2E tests cho device routes.

### Blockers rõ ràng
- BLE discovery/pairing hiện là mock demo trong [`device_mock_data.dart`](lib/features/device/mock/device_mock_data.dart:3).
- `DeviceConnectProvider` còn auto-mock QR recognize/discovery.
- `DeviceProvider` và `DeviceStatusDetailProvider` vẫn có mock branches.
- `DeviceScreen` có debug mock menu nếu bật mock.

### Trạng thái
`BLOCKED_BY_MOCK`

### Để đạt ship E2E
- Tách hẳn demo/mock BLE khỏi production route hoặc disable cứng trong release path.
- Tạo test backend integration cho CRUD + pair/settings.
- Tạo Flutter repository/provider/screen tests cho list/detail/config/pair flows.
- Chứng minh device lifecycle cập nhật dashboard và telemetry surfaces.

---

## 4.10 Health Monitoring / Vital detail

### User-facing flows cần E2E
- xem health report / vital overview
- mở vital detail theo loại chỉ số
- no-data/error/critical states
- linked-profile vitals
- điều hướng từ dashboard / analysis sang vital detail

### Surface liên quan
- Screens/providers: [`HealthReportScreen`](lib/features/health_monitoring/screens/health_report_screen.dart:10), [`VitalDetailScreen`](lib/features/health_monitoring/screens/vital_detail_screen.dart:15), [`VitalSignsProvider`](lib/features/health_monitoring/providers/vital_signs_provider.dart:10), [`MonitoringRepository`](lib/features/health_monitoring/repositories/monitoring_repository.dart:5)
- Router: [`vitalDetail`](lib/core/routes/app_router.dart:224) hiện bọc [`VitalDetailMockProvider`](lib/features/health_monitoring/providers/vital_detail_mock_provider.dart:12)
- Backend surfaces: monitoring + telemetry routes trong [`backend/app/api/routes/monitoring.py`](backend/app/api/routes/monitoring.py), [`backend/app/api/routes/telemetry.py`](backend/app/api/routes/telemetry.py)

### Coverage hiện có
- Không thấy test Flutter riêng cho health_monitoring module.
- Backend telemetry ingest có E2E mạnh ở [`backend/tests/test_e2e_telemetry_real_db.py`](backend/tests/test_e2e_telemetry_real_db.py)
- Nhưng đó mới cover ingest/persistence, chưa cover user-facing vital detail flow.

### Blockers rõ ràng
- Router vẫn inject mock provider tại [`AppRouter.onGenerateRoute()`](lib/core/routes/app_router.dart:224).
- Provider hiện mô phỏng critical/empty/error theo `profileId` giả trong [`VitalDetailMockProvider`](lib/features/health_monitoring/providers/vital_detail_mock_provider.dart:40).
- Trong [`VitalDetailScreen`](lib/features/health_monitoring/screens/vital_detail_screen.dart) còn TODO navigation.
- [`HealthReportScreen`](lib/features/health_monitoring/screens/health_report_screen.dart) còn mockup selector/comment.

### Trạng thái
`BLOCKED_BY_MOCK`

### Để đạt ship E2E
- Thay mock detail provider bằng repository/provider thật.
- Chốt contract cho health report + vital detail APIs.
- Thêm widget-flow tests cho self/linked/critical/no-data/error states.
- Nối từ dashboard/analysis bằng route thật và verify navigation.

---

## 4.11 Profile

### User-facing flows cần E2E
- mở profile shell
- edit profile
- update medical info
- delete account

### Surface liên quan
- Screens/providers: [`ProfileShellScreen`](lib/features/profile/screens/profile_shell_screen.dart:15), [`ProfileScreen`](lib/features/profile/screens/profile_screen.dart:12), [`EditProfileScreen`](lib/features/profile/screens/edit_profile_screen.dart:10), [`MedicalInfoScreen`](lib/features/profile/screens/medical_info_screen.dart:8), [`DeleteAccountScreen`](lib/features/profile/screens/delete_account_screen.dart:9), [`ProfileProvider`](lib/features/profile/providers/profile_provider.dart:6)
- Backend routes: [`get_profile()`](backend/app/api/routes/profile.py:13), [`update_profile()`](backend/app/api/routes/profile.py:18), [`delete_account()`](backend/app/api/routes/profile.py:30)

### Coverage hiện có
- Không thấy test Flutter riêng cho profile module.
- Không thấy backend integration/E2E tests cho profile routes.

### Gaps
- Chưa có chứng minh end-to-end cho edit/save/delete.
- Chưa có bằng chứng auth-protected flow hoạt động xuyên app/backend.

### Trạng thái
`NOT_READY`

### Để đạt ship E2E
- Thêm backend integration tests cho profile CRUD.
- Thêm Flutter form tests và route-flow tests.
- Verify app state sau update profile và sau delete account/logout.

---

## 4.12 Settings

### User-facing flows cần E2E
- load general settings
- update general settings
- settings phản ánh đúng vào app behavior khi cần

### Surface liên quan
- Backend routes: [`get_general_settings()`](backend/app/api/routes/settings.py:16), [`update_general_settings()`](backend/app/api/routes/settings.py:26)
- Mobile settings UI rõ ràng hiện chưa tập trung thành module riêng ngoài sleep settings/local state.

### Coverage hiện có
- Chưa thấy test backend/mobile rõ cho general settings.
- [`SleepSettingsScreen`](lib/features/sleep_analysis/screens/sleep_settings_screen.dart:5) chỉ là local UI/state, không đại diện app settings backend.

### Trạng thái
`NOT_READY`

### Để đạt ship E2E
- Xác định settings nào là release-critical.
- Nối mobile UI với backend settings route nếu thuộc phạm vi app hiện tại.
- Thêm API integration + mobile flow tests.

---

## 4.13 Admin / Supporting backend surfaces

### Surface
- device admin routes ở [`backend/app/api/routes/admin.py`](backend/app/api/routes/admin.py)

### Nhận định
- Có thể phục vụ provisioning/test setup, nhưng không phải user-facing mobile scope chính.
- Nếu release E2E cho mobile phụ thuộc admin provisioning, nên xem đây là setup dependency chứ không phải app journey bắt buộc.

### Trạng thái
`NOT_READY` như một module E2E riêng của app mobile

---

## 5. Mapping flow chéo giữa các module

## 5.1 Release path A — Auth → Dashboard → Risk analysis
1. user login qua [`login()`](backend/app/api/routes/auth.py:150)
2. vào [`HomeDashboardScreen`](lib/features/home/presentation/screens/home_dashboard_screen.dart:151)
3. đọc health/risk summary từ monitoring/risk contract
4. mở [`RiskReportScreen`](lib/features/analysis/presentation/screens/risk_report_screen.dart:17)
5. mở [`RiskReportDetailScreen`](lib/features/analysis/presentation/screens/risk_report_detail_screen.dart:17)
6. mở [`RiskHistoryScreen`](lib/features/analysis/presentation/screens/risk_history_screen.dart:17)

**Hiện trạng:** `PARTIAL` vì auth chưa có API/mobile E2E hoàn chỉnh, risk flow chưa có cross-screen flow test hoàn chỉnh.

## 5.2 Release path B — Telemetry → Sleep → Dashboard preview
1. backend ingest sleep qua [`ingest_sleep_session()`](backend/app/api/routes/telemetry.py:404)
2. DB lưu canonical `sleep_date`
3. read latest/history qua monitoring
4. mobile render [`SleepReportScreen`](lib/features/sleep_analysis/screens/sleep_report_screen.dart:14), [`SleepDetailScreen`](lib/features/sleep_analysis/screens/sleep_detail_screen.dart:12), [`SleepHistoryScreen`](lib/features/sleep_analysis/screens/sleep_history_screen.dart:9)
5. dashboard preview dùng cùng semantics

**Hiện trạng:** `READY` gần đầy đủ; đây là flow mạnh nhất để đưa vào release scope E2E.

## 5.3 Release path C — Telemetry vitals → Risk alert → Critical takeover
1. vitals ingest qua [`ingest_vitals()`](backend/app/api/routes/telemetry.py:160)
2. risk pipeline tạo `risk_high` / `risk_critical`
3. notification/push được gửi
4. mobile parse/open target đúng
5. critical mở fullscreen takeover
6. user acknowledge / request help / timeout escalate

**Hiện trạng:** `PARTIAL` nhưng có backend evidence mạnh; cần device-level matrix trước khi gọi là fully shipped.

## 5.4 Release path D — Linked caregiver view
1. caregiver auth
2. truy cập linked profile qua `X-Target-Profile-Id`
3. xem sleep / risk / dashboard / family data tương ứng

**Hiện trạng:** sleep đã có evidence mạnh; risk/analysis ở mức partial; family dashboard còn blocked by mock.

---

## 6. Danh sách blocker lớn nhất đang ngăn “full app E2E ship”

### Blocker 1 — Family còn mock trong đường nóng
- [`SharedFamilyMockProvider`](lib/features/family/providers/shared_family_mock_provider.dart:8)
- [`FamilyShellScreen`](lib/features/family/screens/family_shell_screen.dart:19)
- [`AddContactScreen`](lib/features/family/screens/add_contact_screen.dart:26)

**Tác động:** caregiver/family domain chưa thể gọi là E2E thật.

### Blocker 2 — Device pairing/status còn demo/mock
- [`device_mock_data.dart`](lib/features/device/mock/device_mock_data.dart:3)
- [`DeviceConnectProvider`](lib/features/device/providers/device_connect_provider.dart:17)
- [`DeviceProvider`](lib/features/device/providers/device_provider.dart:7)
- [`DeviceStatusDetailProvider`](lib/features/device/providers/device_status_detail_provider.dart:20)

**Tác động:** device lifecycle chưa phải production-like user journey.

### Blocker 3 — Vital detail/health monitoring còn mock route
- [`VitalDetailMockProvider`](lib/features/health_monitoring/providers/vital_detail_mock_provider.dart:12)
- router bọc mock ở [`AppRouter.onGenerateRoute()`](lib/core/routes/app_router.dart:224)

**Tác động:** dashboard/monitoring drill-down chưa E2E thật.

### Blocker 4 — Auth thiếu backend API E2E + multi-screen mobile flow
- Có unit/provider/widget tốt nhưng chưa có full login/register/reset journey.

**Tác động:** khó chứng minh release path thật từ cold start → authenticated state.

### Blocker 5 — Notifications inbox chưa được chứng minh độc lập
- Chưa có fetch/detail/read/open-target E2E cho module notifications như một module riêng.

---

## 7. Danh sách hạng mục cần làm để đạt “full app E2E ship”

## P0 — phải hoàn tất trước khi tuyên bố full-app E2E
- [ ] Auth API integration + mobile login/persistent-login flow
- [ ] Family bỏ mock ở shell/dashboard/contact/detail
- [ ] Device bỏ mock BLE/demo path hoặc tách khỏi release scope
- [ ] Health monitoring/vital detail bỏ mock provider trong router
- [ ] Notification inbox/detail/read/open-target coverage
- [ ] Một release matrix pass/fail cho self profile + caregiver profile

## P1 — cần mạnh hóa bằng chứng release
- [ ] Device thật hoặc simulator contract rõ cho pair/connect/update heartbeat
- [ ] Critical risk device-level validation foreground/background/terminated
- [ ] Risk analysis cross-screen flow test
- [ ] Profile/settings API + mobile flow coverage

## P2 — tối ưu chất lượng release
- [ ] `integration_test/` cho 1–2 hành trình vàng trên app thật
- [ ] staging verification checklist riêng ngoài local/live DB E2E
- [ ] artifact evidence (screenshot/log/test report) cho mỗi release path

---

## 8. Ma trận test hiện có theo loại evidence

| Khu vực | Backend live E2E | Backend contract/integration | Flutter provider/repo | Flutter screen/widget-flow | Nhận định |
|---|---|---|---|---|---|
| Auth | Không | Có service/schema/unit | Có | Có register widget | Thiếu API + route-flow |
| Home/Health score | Không riêng | Có monitoring/risk focused verification | Gián tiếp | Có helper tests | Chưa đủ full flow |
| Analysis/Risk | Không riêng | Có contract tests | Có | Chưa có screen-flow | Partial |
| Sleep | Có mạnh | Có | Có | Có mạnh | Ready |
| Emergency manual SOS | Không | Yếu | Ít | Có confirm copy | Partial |
| Risk escalation | Có mạnh | Có mạnh | Có một phần repo | Có helper/overlay | Partial gần ship |
| Notifications | Không | Không rõ | Không rõ | Có helper tests | Partial |
| Family | Không | Không rõ | Không | Không | Mock-blocked |
| Device | Không | Không | Không | Không | Mock-blocked |
| Health monitoring | Không riêng | Gián tiếp ở telemetry | Không rõ | Không | Mock-blocked |
| Profile | Không | Không | Không rõ | Không | Not ready |
| Settings | Không | Không | Không | Không | Not ready |

---

## 9. Release scope đề xuất nếu cần ship E2E theo từng mức

### Mức A — “Core health E2E release” khả thi sớm
Bao gồm:
- Auth login/persistent session
- Sleep
- Health score home
- Risk analysis/history
- Risk notification / critical escalation

**Điều kiện:** hoàn tất auth full flow và chốt risk matrix còn dang dở.

### Mức B — “Caregiver-linked release”
Bao gồm Mức A + linked profile + family dashboard/contact flows.

**Điều kiện:** bỏ hoàn toàn family mock.

### Mức C — “Full app E2E release”
Bao gồm Mức B + device + health monitoring detail + profile/settings + notifications inbox hoàn chỉnh.

**Điều kiện:** xóa các blocker mock còn lại và có coverage tương ứng.

---

## 10. Kết luận điều hành

### Những phần đã có thể xem là hạt nhân E2E của app
- Sleep flow
- Risk notification backend pipeline
- Một phần mạnh của risk escalation
- Health score semantics + analysis data contract

### Những phần đang kéo tụt khả năng tuyên bố “full app E2E”
- Family
- Device
- Health monitoring detail
- Auth end-to-end thật
- Notifications inbox
- Profile/settings

### Kết luận cuối
Nếu nói **toàn bộ health_system đã sẵn sàng ship E2E**, câu trả lời hiện tại là **chưa**.
Nếu thu hẹp thành **core health/risk/sleep release scope**, dự án đã có nền tảng khá mạnh, đặc biệt ở sleep và risk pipeline. Muốn nâng lên “full app E2E ship”, ưu tiên số 1 là loại bỏ các đường nóng còn mock và bổ sung coverage cho auth/family/device/monitoring/notifications/profile.
