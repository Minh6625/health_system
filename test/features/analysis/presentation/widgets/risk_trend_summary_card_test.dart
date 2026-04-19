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
                averageScore: 49,
                highestScore: 61,
                lowestScore: 23,
                deltaVsPreviousPeriod: -4,
                trendPoints: [61, 58, 55, 52, 47, 45, 43],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Điểm trung bình'), findsOneWidget);
    expect(find.text('Cao nhất: 61'), findsOneWidget);
    expect(find.text('Thấp nhất: 23'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
