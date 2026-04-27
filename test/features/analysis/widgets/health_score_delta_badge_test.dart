import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/presentation/widgets/health_score_delta_badge.dart';

Future<void> _pump(
  WidgetTester tester, {
  required double delta,
  String comparedTo = 'lần trước',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: HealthScoreDeltaBadge(
            delta: delta,
            comparedTo: comparedTo,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('HealthScoreDeltaBadge', () {
    testWidgets('positive delta renders + sign and uses success color',
        (tester) async {
      await _pump(tester, delta: 5);
      expect(find.text('+5 so với lần trước'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('negative delta keeps the leading minus sign', (tester) async {
      await _pump(tester, delta: -3);
      expect(find.text('-3 so với lần trước'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    });

    testWidgets('zero / near-zero delta renders the unchanged copy',
        (tester) async {
      await _pump(tester, delta: 0);
      expect(find.text('Không đổi so với lần trước'), findsOneWidget);
      expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
    });

    testWidgets('respects the supplied comparedTo suffix', (tester) async {
      await _pump(tester, delta: 4.5, comparedTo: 'kỳ trước');
      // Halves are rendered with one decimal.
      expect(find.text('+4.5 so với kỳ trước'), findsOneWidget);
    });
  });
}
