import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_detail_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_history_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_report_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_settings_screen.dart';
import 'package:provider/provider.dart';

class _FakeSleepRepository implements SleepRepository {
  _FakeSleepRepository({required this.latest, required this.history})
    : _sessionsByDate = {
        for (final session in history) session.sleepDate: session,
      };

  final SleepSession? latest;
  final List<SleepSession> history;
  final Map<DateTime, SleepSession?> _sessionsByDate;

  @override
  Future<SleepSession?> getLatestSleep({String? patientId}) async => latest;

  @override
  Future<List<SleepSession>> getSleepHistory({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async {
    return history;
  }

  @override
  Future<SleepSession?> getSessionByDate(
    DateTime date, {
    String? patientId,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    return _sessionsByDate[normalized];
  }
}

SleepSession _session({
  required String id,
  required DateTime sleepDate,
  required int sleepMinutes,
  required int qualityScore,
  String qualityLabel = 'GOOD',
}) {
  final normalizedDate = DateTime(
    sleepDate.year,
    sleepDate.month,
    sleepDate.day,
  );
  return SleepSession(
    sessionId: id,
    sleepDate: normalizedDate,
    startTime: normalizedDate.subtract(const Duration(hours: 1)),
    endTime: DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
      6,
      30,
    ),
    inBedMinutes: 420,
    sleepMinutes: sleepMinutes,
    awakeMinutes: 40,
    efficiencyRatio: 0.9,
    qualityScore: qualityScore,
    qualityLabel: qualityLabel,
    wakeCount: 1,
    phases: const SleepPhasesDTO(
      lightMinutes: 210,
      deepMinutes: 90,
      remMinutes: 80,
    ),
  );
}

Widget _buildApp({
  required SleepProvider provider,
  String? profileId,
  DateTime? date,
}) {
  return ChangeNotifierProvider<SleepProvider>.value(
    value: provider,
    child: MaterialApp(
      home: SleepReportScreen(profileId: profileId, date: date),
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;
        switch (settings.name) {
          case '/sleep-detail':
            return MaterialPageRoute<void>(
              builder: (_) => SleepDetailScreen(
                profileId: args?['profileId'] as String?,
                date: args?['date'] as DateTime?,
              ),
            );
          case '/sleep-history':
            return MaterialPageRoute<void>(
              builder: (_) =>
                  SleepHistoryScreen(profileId: args?['profileId'] as String?),
            );
          case '/sleep-settings':
            return MaterialPageRoute<void>(
              builder: (_) => const SleepSettingsScreen(),
            );
        }
        return null;
      },
    ),
  );
}

String _dayLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

void main() {
  testWidgets('self profile flow covers calendar detail history and settings', (
    tester,
  ) async {
    final today = DateTime.now();
    final latest = _session(
      id: 'latest',
      sleepDate: DateTime(today.year, today.month, today.day),
      sleepMinutes: 420,
      qualityScore: 84,
    );
    final previous = _session(
      id: 'previous',
      sleepDate: DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 1)),
      sleepMinutes: 360,
      qualityScore: 70,
      qualityLabel: 'AVERAGE',
    );
    final older = _session(
      id: 'older',
      sleepDate: DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 2)),
      sleepMinutes: 330,
      qualityScore: 58,
      qualityLabel: 'POOR',
    );
    final provider = SleepProvider(
      repository: _FakeSleepRepository(
        latest: latest,
        history: [latest, previous, older],
      ),
      now: () => DateTime(today.year, today.month, today.day, 9),
    );

    await tester.pumpWidget(
      _buildApp(provider: provider, date: previous.sleepDate),
    );
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo Giấc ngủ'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(provider.selectedSession?.sessionId, 'previous');
    expect(find.text(previous.sleepText), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Xem chi tiết'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết giấc ngủ'), findsOneWidget);
    expect(find.text('Hiệu quả giấc ngủ'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Lịch sử giấc ngủ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch sử giấc ngủ'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử giấc ngủ'), findsOneWidget);

    await tester.tap(find.text(_dayLabel(older.sleepDate)).last);
    await tester.pumpAndSettle();

    expect(find.text('Chi tiết giấc ngủ'), findsOneWidget);
    expect(provider.selectedSession?.sessionId, 'older');
    expect(find.text('Hiệu quả giấc ngủ'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử giấc ngủ'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Báo cáo Giấc ngủ'), findsOneWidget);
    expect(find.text(older.sleepText), findsWidgets);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt theo dõi giấc ngủ'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Báo cáo Giấc ngủ'), findsOneWidget);
    expect(provider.selectedSession?.sessionId, 'older');
  });

  testWidgets('linked profile hides settings action on report screen', (
    tester,
  ) async {
    final today = DateTime.now();
    final latest = _session(
      id: 'linked',
      sleepDate: DateTime(today.year, today.month, today.day),
      sleepMinutes: 400,
      qualityScore: 80,
    );
    final provider = SleepProvider(
      repository: _FakeSleepRepository(latest: latest, history: [latest]),
      now: () => DateTime(today.year, today.month, today.day, 9),
    );

    await tester.pumpWidget(_buildApp(provider: provider, profileId: '77'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets(
    'SleepSettingsScreen shows coming-soon disclosure and disables controls',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SleepSettingsScreen()),
      );
      await tester.pumpAndSettle();

      // Disclosure banner is visible.
      expect(find.text('Tính năng đang phát triển'), findsOneWidget);

      // Preview shell still shows both cards regardless of switch state.
      expect(find.text('Theo dõi tự động'), findsOneWidget);
      expect(find.text('Mục tiêu đi ngủ'), findsOneWidget);
      expect(find.text('Nhắc nhở giờ ngủ'), findsOneWidget);

      // Switches are wired with onChanged: null → Material renders them disabled.
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(2));
      expect(switches.every((s) => s.onChanged == null), isTrue);

      // No time picker dialog should open when the disabled bedtime tile is
      // tapped. warnIfMissed: false because the IgnorePointer wrapper is the
      // contract under test — the tap is *expected* to miss its hit target.
      await tester.tap(find.text('Mục tiêu đi ngủ'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
    },
  );
}
