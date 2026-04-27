import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/home/providers/home_dashboard_provider.dart';
import 'package:healthguard/features/home/presentation/widgets/risk_insight_card.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:healthguard/features/home/presentation/widgets/connection_status_strip.dart';
import 'package:healthguard/features/home/presentation/widgets/sleep_insight_card.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_report_screen.dart';
import 'package:provider/provider.dart';

class _StubHomeDashboardProvider extends HomeDashboardProvider {
  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  double? get heartRate => 72;

  @override
  double? get spo2 => 98;

  @override
  double? get temperature => 36.8;

  @override
  double? get bloodPressureSys => 118;

  @override
  double? get bloodPressureDia => 76;

  @override
  bool get vitalsStale => false;

  @override
  DateTime? get latestDashboardTimestamp => DateTime(2026, 4, 17, 8, 30);

  @override
  double? get healthScore => 82;

  @override
  String? get healthLevel => 'Ổn định';

  @override
  String? get healthSummary => 'Dữ liệu sức khỏe ổn định.';

  @override
  String? get riskLevel => 'low';

  @override
  bool get reportStale => false;

  @override
  Map<String, dynamic>? get sleepData => const {
    'in_bed_minutes': 430,
    'quality_score': 86,
    'quality_label': 'GOOD',
    'sleep_date': '2026-04-17',
  };

  @override
  Future<void> loadDashboardData({bool silent = false}) async {}

  @override
  Future<void> refreshDashboard() async {}
}

/// No-op stub so the dashboard's `context.read<ProfileProvider>().fetchProfile()`
/// call in initState doesn't try to hit the network during tests.
class _StubProfileProvider extends ProfileProvider {
  @override
  Future<void> fetchProfile({bool force = false}) async {}
}

class _StubDeviceProvider extends DeviceProvider {
  @override
  List<DeviceModel> get devices => [
    DeviceModel(
      id: 1,
      uuid: 'watch-1',
      deviceName: 'Watch 1',
      deviceType: 'smartwatch',
      isActive: true,
      isOnline: true,
      batteryLevel: 87,
      lastSyncAt: DateTime(2026, 4, 17, 8, 28),
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  List<DeviceModel> get needsAttentionDevices => const [];

  @override
  Future<void> fetchDevices({bool forceRefresh = false}) async {}
}

class _FakeSleepRepository implements SleepRepository {
  _FakeSleepRepository(this.latest);

  final SleepSession latest;

  @override
  Future<SleepSession?> getLatestSleep({String? patientId}) async => latest;

  @override
  Future<List<SleepSession>> getSleepHistory({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async => [latest];

  @override
  Future<SleepSession?> getSessionByDate(
    DateTime date, {
    String? patientId,
  }) async => latest;
}

SleepSession _sleepSession() {
  final sleepDate = DateTime(2026, 4, 17);
  return SleepSession(
    sessionId: 'home-latest',
    sleepDate: sleepDate,
    startTime: DateTime(2026, 4, 16, 22, 45),
    endTime: DateTime(2026, 4, 17, 6, 30),
    inBedMinutes: 465,
    sleepMinutes: 430,
    awakeMinutes: 35,
    efficiencyRatio: 0.92,
    qualityScore: 86,
    qualityLabel: 'GOOD',
    wakeCount: 1,
    phases: const SleepPhasesDTO(
      lightMinutes: 220,
      deepMinutes: 110,
      remMinutes: 100,
    ),
  );
}

Future<int> _loadUnreadCount() async => 0;

Future<void> _pumpDashboardFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Widget _buildDashboardApp() {
  final authProvider = AuthProvider(AuthRepository())
    ..currentUser = UserData(
      userId: 1,
      email: 'tester@example.com',
      fullName: 'Nguyen Test',
      role: 'user',
    );

  final sleepProvider = SleepProvider(
    repository: _FakeSleepRepository(_sleepSession()),
    now: () => DateTime(2026, 4, 17, 9),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<HomeDashboardProvider>(
        create: (_) => _StubHomeDashboardProvider(),
      ),
      ChangeNotifierProvider<DeviceProvider>(
        create: (_) => _StubDeviceProvider(),
      ),
      ChangeNotifierProvider<SleepProvider>.value(value: sleepProvider),
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => _StubProfileProvider(),
      ),
    ],
    child: MaterialApp(
      home: const HomeDashboardScreen(
        enableAutoRefresh: false,
        unreadNotificationCountLoader: _loadUnreadCount,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
    ),
  );
}

void main() {
  group('resolveDashboardConnectionState', () {
    DeviceModel buildDevice({
      required bool isActive,
      required bool isOnline,
      DateTime? lastSyncAt,
    }) {
      return DeviceModel(
        id: 1,
        uuid: 'device-1',
        deviceName: 'Watch 1',
        deviceType: 'smartwatch',
        isActive: isActive,
        isOnline: isOnline,
        lastSyncAt: lastSyncAt,
      );
    }

    test(
      'returns connected when active device is online even if vitals are stale',
      () {
        final now = DateTime(2026, 3, 30, 10, 0, 0);

        final state = resolveDashboardConnectionState(
          activeDevices: [
            buildDevice(
              isActive: true,
              isOnline: true,
              lastSyncAt: now.subtract(const Duration(minutes: 2)),
            ),
          ],
          isStale: true,
          now: now,
        );

        expect(state, DeviceConnectionUiState.connected);
      },
    );

    test(
      'returns connected when active device synced recently even if raw online is false',
      () {
        final now = DateTime(2026, 3, 30, 10, 0, 0);

        final state = resolveDashboardConnectionState(
          activeDevices: [
            buildDevice(
              isActive: true,
              isOnline: false,
              lastSyncAt: now.subtract(const Duration(minutes: 3)),
            ),
          ],
          isStale: true,
          now: now,
        );

        expect(state, DeviceConnectionUiState.connected);
      },
    );

    test(
      'returns offline when active device is stale and not recently synced',
      () {
        final now = DateTime(2026, 3, 30, 10, 0, 0);

        final state = resolveDashboardConnectionState(
          activeDevices: [
            buildDevice(
              isActive: true,
              isOnline: false,
              lastSyncAt: now.subtract(const Duration(minutes: 12)),
            ),
          ],
          isStale: true,
          now: now,
        );

        expect(state, DeviceConnectionUiState.offline);
      },
    );

    test('returns notPaired when there is no active device', () {
      final state = resolveDashboardConnectionState(
        activeDevices: const [],
        isStale: true,
      );

      expect(state, DeviceConnectionUiState.notPaired);
    });
  });

  group('risk mapping helpers', () {
    test(
      'normalizeRiskLevelLabel collapses aliases to low medium critical',
      () {
        expect(normalizeRiskLevelLabel('low'), 'low');
        expect(normalizeRiskLevelLabel('moderate'), 'medium');
        expect(normalizeRiskLevelLabel('high'), 'medium');
        expect(normalizeRiskLevelLabel('critical'), 'critical');
        expect(normalizeRiskLevelLabel(null), isNull);
      },
    );

    test('dashboardRiskDisplayLabel returns Vietnamese user-facing labels', () {
      expect(dashboardRiskDisplayLabel('low'), 'Ổn định');
      expect(dashboardRiskDisplayLabel('moderate'), 'Cảnh báo');
      expect(dashboardRiskDisplayLabel('high'), 'Cảnh báo');
      expect(dashboardRiskDisplayLabel('critical'), 'Nguy hiểm');
      expect(dashboardRiskDisplayLabel(null), 'Không xác định');
    });

    test('dashboardRiskSummary and visual state match normalized levels', () {
      expect(
        dashboardRiskSummary('low'),
        'Các chỉ số đang ổn định. Tiếp tục duy trì thói quen hiện tại nhé.',
      );
      expect(
        dashboardRiskSummary('medium'),
        'Một vài chỉ số đang lệch ngưỡng. Hãy nghỉ ngơi và đo lại sau ít giờ.',
      );
      expect(
        dashboardRiskSummary('critical'),
        'Có chỉ số vượt ngưỡng nguy hiểm. Hãy nghỉ ngơi ngay và liên hệ bác sĩ nếu thấy bất thường.',
      );
      expect(
        dashboardRiskSummary(null),
        'Đang chờ dữ liệu mới từ thiết bị của bạn.',
      );
      expect(dashboardRiskVisualState('low'), RiskVisualState.low);
      expect(dashboardRiskVisualState('medium'), RiskVisualState.moderate);
      expect(dashboardRiskVisualState('high'), RiskVisualState.moderate);
    });

    test(
      'sleepQualityLabelVi reuses API labels and falls back to score thresholds',
      () {
        expect(
          sleepQualityLabelVi(qualityScore: 88, qualityLabel: 'GOOD'),
          'Tốt',
        );
        expect(
          sleepQualityLabelVi(qualityScore: 72, qualityLabel: 'AVERAGE'),
          'Trung bình',
        );
        expect(
          sleepQualityLabelVi(qualityScore: 40, qualityLabel: 'POOR'),
          'Kém',
        );
        expect(
          sleepQualityLabelVi(qualityScore: 85, qualityLabel: null),
          'Tốt',
        );
        expect(
          sleepQualityLabelVi(qualityScore: 65, qualityLabel: ''),
          'Trung bình',
        );
        expect(
          sleepQualityLabelVi(qualityScore: 55, qualityLabel: null),
          'Kém',
        );
      },
    );

    test(
      'dashboardHealthSummary prioritizes backend summary and stale state',
      () {
        expect(
          dashboardHealthSummary(
            backendSummary: 'Sức khỏe hôm nay đang ổn định.',
            isStale: false,
            riskLevel: 'low',
          ),
          'Sức khỏe hôm nay đang ổn định.',
        );
        expect(
          dashboardHealthSummary(
            backendSummary: null,
            isStale: true,
            riskLevel: 'critical',
          ),
          'Dữ liệu đã cũ. Hãy đồng bộ thiết bị để xem đánh giá mới nhất.',
        );
      },
    );
  });

  testWidgets('tapping sleep insight card opens sleep report screen', (
    tester,
  ) async {
    await tester.pumpWidget(_buildDashboardApp());
    await _pumpDashboardFrames(tester);

    expect(find.byType(HomeDashboardScreen), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Giấc ngủ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _pumpDashboardFrames(tester);

    expect(find.byType(SleepInsightCard), findsOneWidget);

    await tester.tap(find.text('Xem chi tiết').last);
    await _pumpDashboardFrames(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SleepReportScreen), findsOneWidget);
    expect(find.text('Báo cáo Giấc ngủ'), findsOneWidget);
  });
}
