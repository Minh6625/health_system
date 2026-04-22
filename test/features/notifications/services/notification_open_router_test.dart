import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/notifications/services/notification_open_router.dart';

void main() {
  group('NotificationOpenRouter helpers', () {
    test('normalizeNotificationRiskLevel maps high to medium', () {
      expect(normalizeNotificationRiskLevel('high'), 'medium');
    });

    test('resolveNotificationRiskLevel maps high + risk_high to medium', () {
      expect(
        resolveNotificationRiskLevel('high', alertType: 'risk_high'),
        'medium',
      );
    });

    test(
      'resolveNotificationRiskLevel falls back to critical for risk_critical',
      () {
        expect(
          resolveNotificationRiskLevel(null, alertType: 'risk_critical'),
          'critical',
        );
      },
    );

    test('parseNotificationOpenTarget parses risk payload without sos id', () {
      final target = parseNotificationOpenTarget({
        'type': 'risk_alert',
        'alert_type': 'risk_high',
        'risk_level': 'high',
        'notification_id': 'notif-42',
        'risk_score_id': '901',
      });

      expect(target, isNotNull);
      expect(target!.type, 'risk');
      expect(target.notificationId, 'notif-42');
      expect(target.alertType, 'risk_high');
      expect(target.riskLevel, 'medium');
      expect(target.riskScoreId, 901);
    });

    test(
      'buildNotificationAndroidCriticalRiskLaunchPayload round-trips through parser',
      () {
        final payload = buildNotificationAndroidCriticalRiskLaunchPayload({
          'type': 'risk_alert',
          'alert_type': 'risk_critical',
          'risk_level': 'critical',
          'notification_id': 'notif-native-1',
          'risk_score_id': '901',
        });

        expect(payload, isNotNull);
        final parsed = parseNotificationAndroidCriticalRiskLaunchPayload(
          payload!,
        );
        expect(parsed, isNotNull);
        expect(parsed!.type, 'risk');
        expect(parsed.notificationId, 'notif-native-1');
        expect(parsed.alertType, 'risk_critical');
        expect(parsed.riskLevel, 'critical');
        expect(parsed.riskScoreId, 901);
      },
    );
  });
}
