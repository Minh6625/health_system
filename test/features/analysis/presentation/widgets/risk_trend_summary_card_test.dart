import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_history_entity.dart';
import 'package:healthguard/features/analysis/presentation/widgets/risk_trend_summary_card.dart';

void main() {
  testWidgets('renders without overflow on compact widths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: RiskTrendSummaryCard(
              summary: RiskHistorySummary(
                averageScore: 49.5,
                highestScore: 61.0,
                lowestScore: 23.0,
                deltaVsPreviousPeriod: -4.5,
                trendPoints: [61, 58, 55, 52, 47, 45, 43],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The summary now reads in the health domain (high = good): the
    // backend's lowest risk score (23) maps to the highest health score
    // (77) and vice versa. Average flips by the same complement.
    expect(find.text('Điểm sức khoẻ trung bình'), findsOneWidget);
    expect(find.text('50.5'), findsOneWidget);
    expect(find.text('Cao nhất: 77'), findsOneWidget);
    expect(find.text('Thấp nhất: 39'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
