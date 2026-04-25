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

    // ------------------------------------------------------------------
    // P1 #5 — buildNotificationAndroidSosLaunchPayload (data-only takeover)
    // ------------------------------------------------------------------

    test(
      'buildNotificationAndroidSosLaunchPayload returns null for non-sos data',
      () {
        final payload = buildNotificationAndroidSosLaunchPayload({
          'type': 'risk_alert',
          'alert_type': 'risk_critical',
        });
        expect(payload, isNull);
      },
    );

    test(
      'buildNotificationAndroidSosLaunchPayload returns null when sos id missing',
      () {
        final payload = buildNotificationAndroidSosLaunchPayload({
          'type': 'sos_alert',
          'alert_type': 'fall_detected',
        });
        expect(payload, isNull);
      },
    );

    test(
      'buildNotificationAndroidSosLaunchPayload builds payload for fall_detected',
      () {
        final payload = buildNotificationAndroidSosLaunchPayload({
          'type': 'sos_alert',
          'sos_id': '88',
          'sos_event_id': '88',
          'alert_type': 'fall_detected',
          'trigger_type': 'auto',
          'notification_id': 'notif-fall-77',
          'title': '',
          'body': '',
        });

        expect(payload, isNotNull);
        expect(payload!['type'], 'sos');
        expect(payload['sosId'], '88');
        expect(payload['sos_id'], '88');
        expect(payload['sos_event_id'], '88');
        expect(payload['alertType'], 'fall_detected');
        expect(payload['alert_type'], 'fall_detected');
        expect(payload['triggerType'], 'auto');
        expect(payload['notification_id'], 'notif-fall-77');
        expect(payload['title'], contains('té ngã'));
      },
    );

    test(
      'buildNotificationAndroidSosLaunchPayload uses manual title for sos trigger',
      () {
        final payload = buildNotificationAndroidSosLaunchPayload({
          'type': 'sos_alert',
          'sos_id': '101',
          'alert_type': 'sos',
          'trigger_type': 'manual',
        });

        expect(payload, isNotNull);
        expect(payload!['type'], 'sos');
        expect(payload['sosId'], '101');
        expect(payload['title'], contains('SOS'));
      },
    );

    test(
      'buildNotificationAndroidSosLaunchPayload prefers explicit title and body',
      () {
        final payload = buildNotificationAndroidSosLaunchPayload({
          'type': 'sos_alert',
          'sos_id': '7',
          'alert_type': 'sos',
          'trigger_type': 'manual',
          'title': 'Bệnh nhân X cần giúp đỡ',
          'body': 'Vui lòng phản hồi ngay',
        });

        expect(payload, isNotNull);
        expect(payload!['title'], 'Bệnh nhân X cần giúp đỡ');
        expect(payload['body'], 'Vui lòng phản hồi ngay');
        expect(payload['message'], 'Vui lòng phản hồi ngay');
      },
    );
  });
}
