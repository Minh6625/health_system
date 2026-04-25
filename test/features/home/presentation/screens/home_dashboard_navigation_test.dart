import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:healthguard/features/home/presentation/widgets/risk_insight_card.dart';
import 'package:healthguard/features/home/presentation/widgets/sleep_insight_card.dart';
import 'package:healthguard/features/home/providers/home_dashboard_provider.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
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
  DateTime? get latestDashboardTimestamp => DateTime(2026, 4, 19, 8, 30);

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
    'sleep_date': '2026-04-18',
  };

  @override
  Future<void> loadDashboardData({bool silent = false}) async {}

  @override
  Future<void> refreshDashboard() async {}
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
      lastSyncAt: DateTime(2026, 4, 19, 8, 28),
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  List<DeviceModel> get needsAttentionDevices => const [];

  @override
  Future<void> fetchDevices({bool forceRefresh = false}) async {}
}

class _CountingSleepProvider extends SleepProvider {
  int loadAllCalls = 0;

  @override
  Future<void> loadAll({
    String? patientId,
    bool forceRefresh = false,
    DateTime? preferredDate,
  }) async {
    loadAllCalls += 1;
  }
}

Future<int> _loadUnreadCount() async => 0;

Future<void> _pumpDashboardFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Widget _buildDashboardApp({
  required _CountingSleepProvider sleepProvider,
  required RouteFactory onGenerateRoute,
  String? profileId,
}) {
  final authProvider = AuthProvider(AuthRepository())
    ..currentUser = UserData(
      userId: 1,
      email: 'tester@example.com',
      fullName: 'Nguyen Test',
      role: 'user',
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
    ],
    child: MaterialApp(
      home: HomeDashboardScreen(
        profileId: profileId,
        enableAutoRefresh: false,
        unreadNotificationCountLoader: _loadUnreadCount,
      ),
      onGenerateRoute: onGenerateRoute,
    ),
  );
}

void main() {
  testWidgets('dashboard forwards linked profile args to risk report route', (
    tester,
  ) async {
    RouteSettings? lastRoute;
    await tester.pumpWidget(
      _buildDashboardApp(
        profileId: '42',
        sleepProvider: _CountingSleepProvider(),
        onGenerateRoute: (settings) {
          lastRoute = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text(settings.name ?? 'unknown')),
          );
        },
      ),
    );
    await _pumpDashboardFrames(tester);

    await tester.scrollUntilVisible(
      find.byType(RiskInsightCard),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<RiskInsightCard>(find.byType(RiskInsightCard)).onTap();
    await tester.pumpAndSettle();
    expect(lastRoute?.name, AppRouter.riskReport);
    expect(lastRoute?.arguments, {'profileId': '42'});
  });

  testWidgets('dashboard forwards linked profile args to sleep report route', (
    tester,
  ) async {
    RouteSettings? lastRoute;
    await tester.pumpWidget(
      _buildDashboardApp(
        profileId: '42',
        sleepProvider: _CountingSleepProvider(),
        onGenerateRoute: (settings) {
          lastRoute = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text(settings.name ?? 'unknown')),
          );
        },
      ),
    );
    await _pumpDashboardFrames(tester);

    await tester.scrollUntilVisible(
      find.byType(SleepInsightCard),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<SleepInsightCard>(find.byType(SleepInsightCard)).onTap();
    await tester.pumpAndSettle();
    expect(lastRoute?.name, AppRouter.sleepReport);
    expect(lastRoute?.arguments, {
      'profileId': '42',
      'date': DateTime(2026, 4, 18),
    });
  });

  testWidgets(
    'dashboard no longer triggers SleepProvider.loadAll during init',
    (tester) async {
      final sleepProvider = _CountingSleepProvider();

      await tester.pumpWidget(
        _buildDashboardApp(
          sleepProvider: sleepProvider,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await _pumpDashboardFrames(tester);

      expect(sleepProvider.loadAllCalls, 0);
    },
  );
}
