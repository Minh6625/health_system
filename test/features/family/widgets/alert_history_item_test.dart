import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/recent_alert_item.dart';
import 'package:healthguard/features/family/widgets/alert_history_item.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

RecentAlertItem _alert({
  RecentAlertType type = RecentAlertType.fallDetected,
  RecentAlertSeverity severity = RecentAlertSeverity.critical,
  bool isResolved = false,
  String title = 'Phát hiện té ngã',
  String? message = 'Confidence 0.92',
}) {
  return RecentAlertItem(
    id: 1,
    uuid: 'uuid-1',
    alertType: type,
    rawAlertType: 'fall_detected',
    severity: severity,
    rawSeverity: 'critical',
    title: title,
    message: message,
    occurredAt: DateTime.now().toUtc(),
    isResolved: isResolved,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('AlertHistoryItem', () {
    testWidgets('renders title, message and severity chip', (tester) async {
      await tester.pumpWidget(
        _wrap(AlertHistoryItem(alert: _alert())),
      );

      expect(find.text('Phát hiện té ngã'), findsOneWidget);
      expect(find.text('Confidence 0.92'), findsOneWidget);
      expect(find.text('Khẩn cấp'), findsOneWidget);
      // No resolved chip when alert is open.
      expect(find.text('Đã xử lý'), findsNothing);
    });

    testWidgets('resolved alerts show the resolved chip', (tester) async {
      await tester.pumpWidget(
        _wrap(AlertHistoryItem(alert: _alert(isResolved: true))),
      );

      expect(find.text('Đã xử lý'), findsOneWidget);
    });

    testWidgets('severity high uses critical accent colour', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlertHistoryItem(
            alert: _alert(severity: RecentAlertSeverity.high),
          ),
        ),
      );

      // The severity chip text uses the accent colour. Walk to its Text and
      // assert the colour matches the high-severity branch.
      final textFinder = find.text('Cao');
      expect(textFinder, findsOneWidget);
      final Text textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, AppColors.critical);
    });

    testWidgets('tap fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AlertHistoryItem(
            alert: _alert(),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Phát hiện té ngã'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('icon mapping picks SOS icon for sosTriggered', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlertHistoryItem(
            alert: _alert(type: RecentAlertType.sosTriggered),
          ),
        ),
      );

      expect(find.byIcon(Icons.sos_rounded), findsOneWidget);
    });

    testWidgets('icon mapping picks bedtime icon for sleep anomaly',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlertHistoryItem(
            alert: _alert(type: RecentAlertType.sleepAnomaly),
          ),
        ),
      );

      expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);
    });
  });
}
