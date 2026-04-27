import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_entity.dart';
import 'package:healthguard/features/analysis/presentation/widgets/first_aid_action_card.dart';

Future<void> _pump(
  WidgetTester tester, {
  required RiskLevel level,
  VoidCallback? onMeasureAgain,
  VoidCallback? onContactFamily,
  VoidCallback? onViewDetails,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FirstAidActionCard(
            level: level,
            onMeasureAgain: onMeasureAgain,
            onContactFamily: onContactFamily,
            onViewDetails: onViewDetails,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FirstAidActionCard - critical', () {
    testWidgets('renders the "Cần xử trí ngay" header and Gọi 115 button',
        (tester) async {
      await _pump(
        tester,
        level: RiskLevel.critical,
        onMeasureAgain: () {},
      );

      expect(find.text('Cần xử trí ngay'), findsOneWidget);
      expect(find.text('Gọi 115'), findsOneWidget);
      expect(find.text('Đo lại ngay'), findsOneWidget);
      // First-aid bullet sample.
      expect(
        find.textContaining('Ngồi hoặc nằm nghỉ'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Gọi 115 ngay nếu đau ngực'),
        findsOneWidget,
      );
    });

    testWidgets('Đo lại ngay invokes the supplied callback', (tester) async {
      var measureCount = 0;
      await _pump(
        tester,
        level: RiskLevel.critical,
        onMeasureAgain: () => measureCount++,
      );

      await tester.tap(find.text('Đo lại ngay'));
      await tester.pump();

      expect(measureCount, 1);
    });

    testWidgets('omits Đo lại ngay when no callback is provided',
        (tester) async {
      await _pump(tester, level: RiskLevel.critical);

      expect(find.text('Gọi 115'), findsOneWidget);
      expect(find.text('Đo lại ngay'), findsNothing);
    });
  });

  group('FirstAidActionCard - medium', () {
    testWidgets('renders Theo dõi sát + Đo lại / Báo người thân buttons',
        (tester) async {
      var measureCount = 0;
      var contactCount = 0;
      await _pump(
        tester,
        level: RiskLevel.medium,
        onMeasureAgain: () => measureCount++,
        onContactFamily: () => contactCount++,
      );

      expect(find.text('Theo dõi sát'), findsOneWidget);
      expect(find.text('Đo lại'), findsOneWidget);
      expect(find.text('Báo người thân'), findsOneWidget);
      // Critical-only labels must not leak in.
      expect(find.text('Gọi 115'), findsNothing);
      expect(find.text('Cần xử trí ngay'), findsNothing);

      await tester.tap(find.text('Đo lại'));
      await tester.tap(find.text('Báo người thân'));
      expect(measureCount, 1);
      expect(contactCount, 1);
    });
  });

  group('FirstAidActionCard - low', () {
    testWidgets('renders Duy trì lối sống tốt + view-details button',
        (tester) async {
      var viewCount = 0;
      await _pump(
        tester,
        level: RiskLevel.low,
        onViewDetails: () => viewCount++,
      );

      expect(find.text('Duy trì lối sống tốt'), findsOneWidget);
      expect(find.text('Xem hướng dẫn duy trì'), findsOneWidget);
      // No emergency button on the calm path.
      expect(find.text('Gọi 115'), findsNothing);
      expect(find.text('Đo lại'), findsNothing);

      await tester.tap(find.text('Xem hướng dẫn duy trì'));
      expect(viewCount, 1);
    });

    testWidgets('hides the action row when no callback is provided',
        (tester) async {
      await _pump(tester, level: RiskLevel.low);

      expect(find.text('Duy trì lối sống tốt'), findsOneWidget);
      expect(find.text('Xem hướng dẫn duy trì'), findsNothing);
    });
  });
}
