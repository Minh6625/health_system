import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/widgets/risk_alert_full_screen_overlay.dart';

Widget buildHarness(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox.expand(child: child)),
  );
}

void main() {
  testWidgets('invokes safe, help, and dismiss callbacks', (tester) async {
    var safeCount = 0;
    var helpCount = 0;
    var dismissCount = 0;
    var timeoutCount = 0;

    await tester.pumpWidget(
      buildHarness(
        RiskAlertFullScreenOverlay(
          title: 'Cảnh báo sức khỏe',
          message: 'Chỉ số đang thay đổi',
          riskLevel: 'critical',
          alertType: 'risk_critical',
          countdownSeconds: 10,
          onConfirmOk: () async {
            safeCount += 1;
          },
          onRequestHelp: () async {
            helpCount += 1;
          },
          onTimeoutEscalated: () async {
            timeoutCount += 1;
          },
          onDismiss: () async {
            dismissCount += 1;
          },
        ),
      ),
    );

    await tester.tap(find.text('Tôi ổn'));
    await tester.pump();
    expect(safeCount, 1);
    expect(helpCount, 0);
    expect(timeoutCount, 0);

    await tester.tap(find.text('Tôi cần giúp đỡ'));
    await tester.pump();
    expect(helpCount, 1);

    await tester.tap(find.text('Đóng'));
    await tester.pump();
    expect(dismissCount, 1);
  });

  testWidgets('timeout escalates through the dedicated timeout callback', (
    tester,
  ) async {
    var safeCount = 0;
    var helpCount = 0;
    var dismissCount = 0;
    var timeoutCount = 0;

    await tester.pumpWidget(
      buildHarness(
        RiskAlertFullScreenOverlay(
          title: 'Cảnh báo sức khỏe',
          message: 'Chỉ số đang thay đổi',
          riskLevel: 'medium',
          alertType: 'risk_medium',
          countdownSeconds: 1,
          onConfirmOk: () async {
            safeCount += 1;
          },
          onRequestHelp: () async {
            helpCount += 1;
          },
          onTimeoutEscalated: () async {
            timeoutCount += 1;
          },
          onDismiss: () async {
            dismissCount += 1;
          },
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(timeoutCount, 1);
    expect(helpCount, 0);
    expect(safeCount, 0);
    expect(dismissCount, 0);
  });
}
