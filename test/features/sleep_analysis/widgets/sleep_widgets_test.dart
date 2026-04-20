import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/widgets/empty_sleep_view.dart';
import 'package:healthguard/features/sleep_analysis/widgets/no_data_tonight_view.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_hero_card.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_trend_chart.dart';

SleepSession _session({
  required String id,
  required DateTime sleepDate,
  required int qualityScore,
  required String qualityLabel,
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
    sleepMinutes: 380,
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

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('EmptySleepView and NoDataTonightView render canonical copy', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const EmptySleepView()));
    expect(find.text('Chưa có dữ liệu giấc ngủ'), findsOneWidget);

    await tester.pumpWidget(_wrap(const NoDataTonightView()));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu đêm nay chưa sẵn sàng'), findsOneWidget);
  });

  testWidgets('SleepHeroCard renders badge and AI message for GOOD session', (
    tester,
  ) async {
    final session = _session(
      id: 'good',
      sleepDate: DateTime.now(),
      qualityScore: 88,
      qualityLabel: 'GOOD',
    );

    await tester.pumpWidget(
      _wrap(SleepHeroCard(session: session, selectedDate: session.sleepDate)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Bác sĩ'), findsOneWidget);
    expect(find.text('Tốt'), findsOneWidget);
    expect(find.text(session.sleepText), findsOneWidget);
  });

  testWidgets(
    'SleepTrendChart renders history labels and handles tap callback',
    (tester) async {
      final sessions = [
        _session(
          id: 'd1',
          sleepDate: DateTime.now().subtract(const Duration(days: 2)),
          qualityScore: 60,
          qualityLabel: 'AVERAGE',
        ),
        _session(
          id: 'd2',
          sleepDate: DateTime.now().subtract(const Duration(days: 1)),
          qualityScore: 82,
          qualityLabel: 'GOOD',
        ),
      ];
      SleepSession? tappedSession;

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 220,
            child: SleepTrendChart(
              historyList: sessions,
              highlightedDate: sessions.last.sleepDate,
              onSessionTapped: (session) {
                tappedSession = session;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('/'), findsWidgets);
      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final touchedGroup = barChart.data.barGroups.last;
      final touchedRod = touchedGroup.barRods.first;
      barChart.data.barTouchData.touchCallback?.call(
        FlTapDownEvent(
          TapDownDetails(
            localPosition: Offset(10, 10),
            globalPosition: Offset(10, 10),
          ),
        ),
        BarTouchResponse(
          BarTouchedSpot(
            touchedGroup,
            barChart.data.barGroups.length - 1,
            touchedRod,
            0,
            null,
            -1,
            FlSpot(
              (barChart.data.barGroups.length - 1).toDouble(),
              touchedRod.toY,
            ),
            const Offset(10, 10),
          ),
        ),
      );
      await tester.pump();

      expect(tappedSession, isNotNull);
    },
  );
}
