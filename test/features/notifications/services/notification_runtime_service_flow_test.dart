import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/notifications/models/notification_open_target.dart';
import 'package:healthguard/features/notifications/services/notification_runtime_service.dart';

class _FakeNotificationEmergencyAdapter implements NotificationEmergencyAdapter {
  final List<String> notificationsOpened = <String>[];
  final List<String> openedSosIds = <String>[];
  final List<NotificationOpenTarget> openedTargets = <NotificationOpenTarget>[];
  final List<NotificationOpenTarget> redirectedTargets =
      <NotificationOpenTarget>[];

  @override
  Future<void> openNotifications() async {
    notificationsOpened.add('notifications');
  }

  @override
  Future<void> openSosDetail(String sosId) async {
    openedSosIds.add(sosId);
  }

  @override
  Future<void> presentCriticalRiskTarget(NotificationOpenTarget target) async {
    openedTargets.add(target);
  }

  @override
  Future<void> presentFullscreenAlert(
    Map<String, dynamic> item, {
    required String subjectId,
  }) async {}

  @override
  Future<void> presentMissedAlert(
    Map<String, dynamic> item, {
    required String subjectId,
  }) async {}

  @override
  Future<void> redirectCriticalAlertToAuth(NotificationOpenTarget target) async {
    redirectedTargets.add(target);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'medium risk opens notifications while critical risk opens target presenter',
    () async {
      final adapter = _FakeNotificationEmergencyAdapter();
      final service = NotificationRuntimeService(
        emergencyAdapter: adapter,
      );

      await service.handleRemoteMessageOpenForTest(<String, dynamic>{
        'type': 'risk_alert',
        'alert_type': 'risk_high',
        'risk_level': 'high',
        'notification_id': 'notif-medium',
      });
      await service.handleRemoteMessageOpenForTest(<String, dynamic>{
        'type': 'risk_alert',
        'alert_type': 'risk_critical',
        'risk_level': 'critical',
        'notification_id': 'notif-critical',
      });

      expect(adapter.notificationsOpened, <String>['notifications']);
      expect(adapter.openedTargets, hasLength(1));
      expect(adapter.openedTargets.single.notificationId, 'notif-critical');
    },
  );
}
