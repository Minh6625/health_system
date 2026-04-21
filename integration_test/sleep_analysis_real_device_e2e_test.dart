import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/app.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:healthguard/features/home/providers/home_dashboard_provider.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_detail_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_history_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_report_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'helpers/e2e_test_config.dart';

const _patientEmail = 'e2e.dashboard.patient@example.com';
const _patientPassword = 'PatientE2E!123';
const _caregiverEmail = 'e2e.dashboard.caregiver@example.com';
const _caregiverPassword = 'CaregiverE2E!123';
const _emptySleepEmail = 'e2e.sleep.empty@example.com';
const _emptySleepPassword = 'SleepEmptyE2E!123';
Finder _textFieldWithLabel(String label) {
  final fields = find.byType(TextFormField);
  return switch (label) {
    'Email' => fields.first,
    'Mật khẩu' => fields.last,
    _ => fields,
  };
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> _launchApp(
  WidgetTester tester, {
  DateTime Function()? sleepNow,
}) async {
  await AuthSessionService.shared.clearSession();
  await loadE2ETestConfig(mockDevice: false);
  await tester.pumpWidget(HealthSystemApp(sleepNow: sleepNow));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openLoginForm(WidgetTester tester) async {
  final pageView = find.byType(PageView);
  await _pumpUntilVisible(tester, pageView);
  await tester.drag(pageView, const Offset(-450, 0));
  await tester.pumpAndSettle();
  await _pumpUntilVisible(tester, _textFieldWithLabel('Email'));
}

Future<void> _activateElevatedButton(WidgetTester tester, String label) async {
  final buttonFinder = find.widgetWithText(ElevatedButton, label);
  await _pumpUntilVisible(tester, buttonFinder);
  tester.widget<ElevatedButton>(buttonFinder).onPressed?.call();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _login(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await _openLoginForm(tester);
  await tester.enterText(_textFieldWithLabel('Email'), email);
  await tester.enterText(_textFieldWithLabel('Mật khẩu'), password);
  await _activateElevatedButton(tester, 'ĐĂNG NHẬP');
  await _pumpUntilVisible(
    tester,
    find.byType(HomeDashboardScreen),
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _pageBack(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pushNamed(
  WidgetTester tester,
  String route, {
  Map<String, dynamic>? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pushNamed(route, arguments: arguments);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<String> _loadFirstLinkedProfileId(WidgetTester tester) async {
  final profiles = await tester.runAsync(
    () => FamilyRepository().getFamilyDashboard(),
  );
  if (profiles == null || profiles.isEmpty) {
    fail('Expected at least one linked profile for caregiver sleep E2E test.');
  }
  return profiles.first.id;
}

T _readProvider<T>(WidgetTester tester, Finder finder) {
  final context = tester.element(finder.first);
  return Provider.of<T>(context, listen: false);
}

DateTime _normalizedDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime? _dashboardSleepDate(WidgetTester tester) {
  final provider = _readProvider<HomeDashboardProvider>(
    tester,
    find.byType(HomeDashboardScreen),
  );
  return canonicalSleepDateFromPayload(provider.sleepData);
}

Future<DateTime> _waitForDashboardSleepDate(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final sleepDate = _dashboardSleepDate(tester);
    if (sleepDate != null) {
      return sleepDate;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('Timed out waiting for dashboard sleep preview to load.');
}

Future<SleepProvider> _openSleepReport(
  WidgetTester tester, {
  String? profileId,
  required DateTime sleepDate,
}) async {
  await _pushNamed(
    tester,
    AppRouter.sleepReport,
    arguments: {'profileId': profileId, 'date': sleepDate},
  );
  await _pumpUntilVisible(
    tester,
    find.byKey(const ValueKey('sleep-report-screen')),
  );
  return _waitForReportProvider(tester);
}

Future<SleepProvider> _waitForReportProvider(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final provider = _readProvider<SleepProvider>(
      tester,
      find.byType(SleepReportScreen),
    );
    if (provider.selectedSession != null ||
        provider.isEmpty ||
        provider.isNoDataYet ||
        provider.hasError) {
      return provider;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('Timed out waiting for sleep report state to settle.');
}

Future<SleepProvider> _waitForDetailProvider(
  WidgetTester tester, {
  DateTime? expectedDate,
  String? expectedSessionId,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (find.byType(SleepDetailScreen).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      continue;
    }

    final provider = _readProvider<SleepProvider>(
      tester,
      find.byType(SleepDetailScreen),
    );
    final sessionMatches =
        expectedSessionId == null ||
        provider.selectedSession?.sessionId == expectedSessionId;
    final dateMatches =
        expectedDate == null ||
        _normalizedDay(provider.selectedDate) == _normalizedDay(expectedDate);
    if (sessionMatches && dateMatches) {
      return provider;
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('Timed out waiting for sleep detail state to settle.');
}

Future<SleepProvider> _openSleepDetailFromReport(
  WidgetTester tester, {
  String? profileId,
  required DateTime date,
}) async {
  await _pushNamed(
    tester,
    AppRouter.sleepDetail,
    arguments: {'profileId': profileId, 'date': date},
  );
  await _pumpUntilVisible(
    tester,
    find.byKey(const ValueKey('sleep-detail-screen')),
  );
  return _waitForDetailProvider(tester, expectedDate: date);
}

Future<void> _openSleepHistoryFromReport(
  WidgetTester tester, {
  String? profileId,
}) async {
  await _pushNamed(
    tester,
    AppRouter.sleepHistory,
    arguments: {'profileId': profileId},
  );
  await _pumpUntilVisible(
    tester,
    find.byKey(const ValueKey('sleep-history-screen')),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sleep Analysis real-device E2E', () {
    testWidgets(
      'self flow keeps canonical sleep_date across dashboard report detail and history detail',
      (WidgetTester tester) async {
        await _launchApp(tester);
        await _login(tester, email: _patientEmail, password: _patientPassword);

        final dashboardSleepDate = await _waitForDashboardSleepDate(tester);

        final reportProvider = await _openSleepReport(
          tester,
          sleepDate: dashboardSleepDate,
        );
        expect(
          _normalizedDay(reportProvider.selectedDate),
          _normalizedDay(dashboardSleepDate),
        );
        expect(reportProvider.selectedSession, isNotNull);

        final detailProvider = await _openSleepDetailFromReport(
          tester,
          date: reportProvider.selectedDate,
        );
        expect(
          _normalizedDay(detailProvider.selectedDate),
          _normalizedDay(dashboardSleepDate),
        );

        await _pageBack(tester);
        await _pumpUntilVisible(tester, find.text('Báo cáo Giấc ngủ'));

        await _openSleepHistoryFromReport(tester);

        final historyProvider = _readProvider<SleepProvider>(
          tester,
          find.byType(SleepHistoryScreen),
        );
        expect(historyProvider.historyList, isNotEmpty);
        final targetSession = historyProvider.historyList.first;
        final historyItem = find.byKey(
          ValueKey('sleep-history-item-${targetSession.sessionId}'),
        );
        await _pumpUntilVisible(tester, historyItem);
        await tester.ensureVisible(historyItem);
        await tester.tap(historyItem);
        await tester.pump(const Duration(milliseconds: 300));
        await _pumpUntilVisible(
          tester,
          find.byKey(const ValueKey('sleep-detail-screen')),
        );

        final historyDetailProvider = await _waitForDetailProvider(
          tester,
          expectedDate: targetSession.sleepDate,
          expectedSessionId: targetSession.sessionId,
        );
        expect(
          historyDetailProvider.selectedSession?.sessionId,
          targetSession.sessionId,
        );
        expect(
          _normalizedDay(historyDetailProvider.selectedDate),
          _normalizedDay(targetSession.sleepDate),
        );
      },
    );

    testWidgets(
      'linked profile flow keeps profile context and hides local settings',
      (WidgetTester tester) async {
        await _launchApp(tester);
        await _login(
          tester,
          email: _caregiverEmail,
          password: _caregiverPassword,
        );

        final linkedProfileId = await _loadFirstLinkedProfileId(tester);
        await _pushNamed(
          tester,
          AppRouter.dashboard,
          arguments: {'profileId': linkedProfileId},
        );
        await _pumpUntilVisible(tester, find.text('Điểm sức khoẻ hôm nay'));

        final dashboardSleepDate = await _waitForDashboardSleepDate(tester);

        final reportProvider = await _openSleepReport(
          tester,
          profileId: linkedProfileId,
          sleepDate: dashboardSleepDate,
        );
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
        expect(
          _normalizedDay(reportProvider.selectedDate),
          _normalizedDay(dashboardSleepDate),
        );

        await _openSleepHistoryFromReport(tester, profileId: linkedProfileId);

        final historyProvider = _readProvider<SleepProvider>(
          tester,
          find.byType(SleepHistoryScreen),
        );
        expect(historyProvider.historyList, isNotEmpty);
        final targetSession = historyProvider.historyList.first;

        final historyItem = find.byKey(
          ValueKey('sleep-history-item-${targetSession.sessionId}'),
        );
        await _pumpUntilVisible(tester, historyItem);
        await tester.ensureVisible(historyItem);
        await tester.tap(historyItem);
        await tester.pump(const Duration(milliseconds: 300));
        await _pumpUntilVisible(
          tester,
          find.byKey(const ValueKey('sleep-detail-screen')),
        );

        final detailProvider = await _waitForDetailProvider(
          tester,
          expectedDate: targetSession.sleepDate,
          expectedSessionId: targetSession.sessionId,
        );
        expect(
          detailProvider.selectedSession?.sessionId,
          targetSession.sessionId,
        );
      },
    );

    testWidgets('empty account shows empty latest and empty history states', (
      WidgetTester tester,
    ) async {
      await _launchApp(tester);
      await _login(
        tester,
        email: _emptySleepEmail,
        password: _emptySleepPassword,
      );

      await _pushNamed(tester, AppRouter.sleepReport);
      await _pumpUntilVisible(tester, find.text('Báo cáo Giấc ngủ'));
      await _pumpUntilVisible(tester, find.text('Chưa có dữ liệu giấc ngủ'));
      expect(find.text('Chưa có dữ liệu giấc ngủ'), findsOneWidget);

      await _pushNamed(tester, AppRouter.sleepHistory);
      await _pumpUntilVisible(tester, find.text('Lịch sử giấc ngủ'));
      await _pumpUntilVisible(tester, find.text('Chưa có dữ liệu lịch sử.'));
      expect(find.text('Chưa có dữ liệu lịch sử.'), findsOneWidget);
    });

    testWidgets('before 6am route shows NoDataTonightView deterministically', (
      WidgetTester tester,
    ) async {
      final deviceNow = DateTime.now();
      final fakeSleepNow = DateTime(
        deviceNow.year,
        deviceNow.month,
        deviceNow.day + 1,
        5,
        30,
      );

      await _launchApp(tester, sleepNow: () => fakeSleepNow);
      await _login(tester, email: _patientEmail, password: _patientPassword);

      await _pushNamed(
        tester,
        AppRouter.sleepReport,
        arguments: {'date': _normalizedDay(fakeSleepNow)},
      );
      await _pumpUntilVisible(tester, find.text('Báo cáo Giấc ngủ'));
      await _pumpUntilVisible(
        tester,
        find.text('Dữ liệu đêm nay chưa sẵn sàng'),
      );
      expect(find.text('Dữ liệu đêm nay chưa sẵn sàng'), findsOneWidget);
    });

    testWidgets(
      'settings stays local and does not reset the active sleep session',
      (WidgetTester tester) async {
        await _launchApp(tester);
        await _login(tester, email: _patientEmail, password: _patientPassword);
        final dashboardSleepDate = await _waitForDashboardSleepDate(tester);
        final reportProvider = await _openSleepReport(
          tester,
          sleepDate: dashboardSleepDate,
        );
        final baselineSessionId = reportProvider.selectedSession?.sessionId;
        expect(baselineSessionId, isNotNull);

        await tester.tap(
          find.byKey(const ValueKey('sleep-report-settings-button')),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await _pumpUntilVisible(tester, find.text('Cài đặt theo dõi giấc ngủ'));

        final firstSwitch = find.byType(Switch).first;
        await tester.tap(firstSwitch);
        await tester.pump(const Duration(milliseconds: 300));

        await _pageBack(tester);
        await _pumpUntilVisible(tester, find.text('Báo cáo Giấc ngủ'));

        final reportAfterBack = _readProvider<SleepProvider>(
          tester,
          find.byType(SleepReportScreen),
        );
        expect(reportAfterBack.selectedSession?.sessionId, baselineSessionId);
      },
    );
  });
}
