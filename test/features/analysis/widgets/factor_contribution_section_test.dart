import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_detail_entity.dart';
import 'package:healthguard/features/analysis/presentation/widgets/factor_contribution_section.dart';

FactorBreakdown _factor({
  required String label,
  required double contribution,
  String impactLevel = 'medium',
  String routeTarget = 'vital_hr',
}) {
  return FactorBreakdown(
    key: label,
    label: label,
    contributionScore: contribution,
    impactLevel: impactLevel,
    value: '--',
    unit: 'bpm',
    routeTarget: routeTarget,
  );
}

Future<void> _pump(WidgetTester tester, List<FactorBreakdown> items) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FactorContributionSection(breakdown: items),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('with <=3 factors, no expand toggle is rendered', (tester) async {
    await _pump(tester, [
      _factor(label: 'Nhịp tim', contribution: 12.0),
      _factor(label: 'SpO2', contribution: 7.0),
      _factor(label: 'Huyết áp', contribution: 4.0),
    ]);

    expect(find.text('Nhịp tim'), findsOneWidget);
    expect(find.text('SpO2'), findsOneWidget);
    expect(find.text('Huyết áp'), findsOneWidget);
    expect(find.textContaining('Xem thêm'), findsNothing);
    expect(find.textContaining('Thu gọn'), findsNothing);
  });

  testWidgets(
    'with >3 factors, only the 3 highest-contribution ones are shown by default '
    'and a "Xem thêm N yếu tố" toggle reveals the rest',
    (tester) async {
      await _pump(tester, [
        // Intentionally unsorted to verify _sorted picks the top 3.
        _factor(label: 'HRV', contribution: 2.0),
        _factor(label: 'Nhịp tim', contribution: 12.0),
        _factor(label: 'Huyết áp', contribution: 4.0),
        _factor(label: 'Nhiệt độ', contribution: 1.0),
        _factor(label: 'SpO2', contribution: 7.0),
      ]);

      // Default collapsed state — top 3 only.
      expect(find.text('Nhịp tim'), findsOneWidget); // 12
      expect(find.text('SpO2'), findsOneWidget); // 7
      expect(find.text('Huyết áp'), findsOneWidget); // 4
      expect(find.text('HRV'), findsNothing);
      expect(find.text('Nhiệt độ'), findsNothing);

      // Toggle is present and reflects the hidden count.
      expect(find.text('Xem thêm 2 yếu tố'), findsOneWidget);
      expect(find.text('3 / 5'), findsOneWidget);

      // Tap to expand.
      await tester.tap(find.text('Xem thêm 2 yếu tố'));
      await tester.pumpAndSettle();

      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('Nhiệt độ'), findsOneWidget);
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);

      // Tap again to collapse.
      await tester.tap(find.text('Thu gọn'));
      await tester.pumpAndSettle();

      expect(find.text('HRV'), findsNothing);
      expect(find.text('Xem thêm 2 yếu tố'), findsOneWidget);
    },
  );

  testWidgets('empty breakdown renders nothing', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Mức độ đóng góp của các yếu tố'), findsNothing);
  });
}
