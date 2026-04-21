import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/screens/sos_confirm_screen.dart';
import 'package:healthguard/features/emergency/services/sos_realtime_alert_service.dart';
import 'package:healthguard/features/emergency/widgets/risk_alert_full_screen_overlay.dart';
import 'package:integration_test/integration_test.dart';

class _RiskOverlayHarness extends StatefulWidget {
  const _RiskOverlayHarness({required this.countdownSeconds});

  final int countdownSeconds;

  @override
  State<_RiskOverlayHarness> createState() => _RiskOverlayHarnessState();
}

class _RiskOverlayHarnessState extends State<_RiskOverlayHarness> {
  String state = 'overlay';

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (state) {
      case 'safe':
        child = const Center(child: Text('safe-acknowledged'));
        break;
      case 'timeout':
        child = const Center(child: Text('timeout-escalated'));
        break;
      case 'dismissed':
        child = const Center(child: Text('dismissed'));
        break;
      case 'confirm':
        child = SosConfirmScreen(
          recipientCount: 3,
          mode: SosConfirmMode.riskEscalation,
        );
        break;
      default:
        child = RiskAlertFullScreenOverlay(
          title: 'Cảnh báo sức khỏe',
          message: 'Chỉ số đang ở mức nguy hiểm',
          riskLevel: 'critical',
          alertType: 'risk_critical',
          countdownSeconds: widget.countdownSeconds,
          onConfirmOk: () async {
            setState(() {
              state = 'safe';
            });
          },
          onRequestHelp: () async {
            setState(() {
              state = 'confirm';
            });
          },
          onTimeoutEscalated: () async {
            setState(() {
              state = 'timeout';
            });
          },
          onDismiss: () async {
            setState(() {
              state = 'dismissed';
            });
          },
        );
        break;
    }

    return MaterialApp(
      home: Scaffold(body: SizedBox.expand(child: child)),
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('foreground critical risk overlay accepts safe response', (
    tester,
  ) async {
    await tester.pumpWidget(const _RiskOverlayHarness(countdownSeconds: 30));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('risk-alert-fullscreen-overlay')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('risk-alert-safe-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('safe-acknowledged'), findsOneWidget);
  });

  testWidgets('help requested path opens risk escalation confirm mode', (
    tester,
  ) async {
    await tester.pumpWidget(const _RiskOverlayHarness(countdownSeconds: 30));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('risk-alert-help-button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('sos-confirm-screen')), findsOneWidget);
    expect(find.text('Đã chuyển cảnh báo'), findsOneWidget);
  });

  testWidgets('timeout escalation and auth replay path can be restored', (
    tester,
  ) async {
    await tester.pumpWidget(const _RiskOverlayHarness(countdownSeconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('timeout-escalated'), findsOneWidget);

    final openedTargets = <String>[];
    final redirectedTargets = <String>[];
    final service = SOSRealtimeAlertService.test(
      riskAlertTargetPresenter: (target) async {
        openedTargets.add(target.notificationId ?? '');
      },
      criticalAlertAuthRedirector: (target) async {
        redirectedTargets.add(target.notificationId ?? '');
      },
    );
    const replayTarget = RealtimeNotificationOpenTarget(
      type: 'risk',
      notificationId: 'notif-auth-replay',
      alertType: 'risk_critical',
      riskLevel: 'critical',
      title: 'Replay',
      message: 'Open after login',
    );

    await service.handleAndroidCriticalAlertLaunchForTest(
      '{"type":"risk","notificationId":"notif-native-launch","alertType":"risk_critical","riskLevel":"critical","title":"Launch","message":"Native"}',
    );
    await service.redirectCriticalAlertToAuthForTest(replayTarget);
    service.setRealtimeEnabledForTest(true);
    await service.restorePendingCriticalAlertAfterAuthForTest();

    expect(redirectedTargets, <String>['notif-auth-replay']);
    expect(openedTargets, <String>['notif-native-launch', 'notif-auth-replay']);
  });
}
