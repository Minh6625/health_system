import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/notifications/services/notification_event_mapper.dart';

void main() {
  group('Notification event mapper', () {
    test(
      'mapNotificationEventFromPushData maps risk push into normalized unread event',
      () {
        final event = mapNotificationEventFromPushData(<String, dynamic>{
          'type': 'risk_alert',
          'alert_type': 'risk_high',
          'risk_level': 'high',
          'notification_id': 'notif-medium-1',
          'risk_score_id': '77',
        });

        expect(event, isNotNull);
        expect(event!.id, 'notif-medium-1');
        expect(event.alertType, 'risk_high');
        expect(event.severity, 'medium');
        expect(event.isRead, isFalse);
        expect(event.data['risk_score_id'], '77');
      },
    );

    test('isActionableNotificationType matches supported types', () {
      expect(isActionableNotificationType('risk_critical'), isTrue);
      expect(isActionableNotificationType('sos'), isTrue);
      expect(isActionableNotificationType('fall_detected'), isTrue);
      expect(isActionableNotificationType('medication_missed'), isFalse);
    });

    test('extractNotificationSubjectId falls back for risk alerts', () {
      expect(
        extractNotificationSubjectId(<String, dynamic>{
          'alert_type': 'risk_high',
          'id': 'notif-medium-1',
          'data': <String, dynamic>{'notification_id': 'notif-medium-1'},
        }),
        'notif-medium-1',
      );

      expect(
        extractNotificationSubjectId(<String, dynamic>{
          'alert_type': 'risk_high',
          'id': 'notif-medium-2',
          'data': <String, dynamic>{},
        }),
        'notif-medium-2',
      );
    });
  });
}
