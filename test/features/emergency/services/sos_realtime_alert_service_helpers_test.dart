import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/services/sos_realtime_alert_service.dart';

void main() {
  group('Realtime notification helpers', () {
    test('normalizes legacy high risk level to medium', () {
      expect(normalizeRealtimeRiskLevel('high'), 'medium');
      expect(
        resolveRealtimeRiskLevel('high', alertType: 'risk_high'),
        'medium',
      );
      expect(
        resolveRealtimeRiskLevel(null, alertType: 'risk_critical'),
        'critical',
      );
    });

    test('parses risk push open target without requiring sos id', () {
      final target = parseRealtimeNotificationOpenTarget({
        'type': 'risk_alert',
        'alert_type': 'risk_high',
        'risk_level': 'high',
        'notification_id': 'notif-42',
        'risk_score_id': '901',
        'title': 'Risk warning',
        'body': 'Check vitals now',
      });

      expect(target, isNotNull);
      expect(target!.type, 'risk');
      expect(target.notificationId, 'notif-42');
      expect(target.alertType, 'risk_high');
      expect(target.riskLevel, 'medium');
      expect(target.riskScoreId, 901);
    });

    test('parses sos push open target from remote payload', () {
      final target = parseRealtimeNotificationOpenTarget({
        'type': 'sos_alert',
        'sos_id': 'sos-77',
        'title': 'SOS',
      });

      expect(target, isNotNull);
      expect(target!.type, 'sos');
      expect(target.sosId, 'sos-77');
    });

    test('builds Android critical-risk launch payload for native takeover', () {
      final payload = buildAndroidCriticalRiskLaunchPayload({
        'type': 'risk_alert',
        'alert_type': 'risk_critical',
        'risk_level': 'critical',
        'notification_id': 'notif-critical-1',
        'risk_score_id': '7788',
        'title': 'Critical risk',
        'body': 'Wake the device now',
      });

      expect(payload, isNotNull);
      expect(payload!['type'], 'risk');
      expect(payload['notificationId'], 'notif-critical-1');
      expect(payload['notification_id'], 'notif-critical-1');
      expect(payload['alertType'], 'risk_critical');
      expect(payload['alert_type'], 'risk_critical');
      expect(payload['riskLevel'], 'critical');
      expect(payload['risk_level'], 'critical');
      expect(payload['riskScoreId'], 7788);
      expect(payload['risk_score_id'], 7788);
      expect(payload['title'], 'Critical risk');
      expect(payload['body'], 'Wake the device now');
      expect(payload['message'], 'Wake the device now');
    });

    test('does not build Android takeover payload for non-critical risk', () {
      final payload = buildAndroidCriticalRiskLaunchPayload({
        'type': 'risk_alert',
        'alert_type': 'risk_high',
        'risk_level': 'high',
        'notification_id': 'notif-high-1',
        'title': 'High risk',
        'body': 'Stay on notification-only flow',
      });

      expect(payload, isNull);
    });

    test(
      'parses Android critical-risk launch payload only for critical risk',
      () {
        final criticalTarget = parseAndroidCriticalRiskLaunchPayload(
          '{"type":"risk","notificationId":"notif-native-9","alertType":"risk_critical","riskLevel":"critical","riskScoreId":901,"title":"Critical","message":"Open takeover"}',
        );

        expect(criticalTarget, isNotNull);
        expect(criticalTarget!.type, 'risk');
        expect(criticalTarget.notificationId, 'notif-native-9');
        expect(criticalTarget.alertType, 'risk_critical');
        expect(criticalTarget.riskLevel, 'critical');
        expect(criticalTarget.riskScoreId, 901);

        final highTarget = parseAndroidCriticalRiskLaunchPayload({
          'type': 'risk',
          'notificationId': 'notif-native-high',
          'alertType': 'risk_high',
          'riskLevel': 'medium',
        });

        expect(highTarget, isNull);
      },
    );
  });
}
