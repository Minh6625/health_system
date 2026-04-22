import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/services/token_storage_service.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/emergency/services/sos_realtime_alert_service.dart';
import 'package:healthguard/features/notifications/services/notification_runtime_service.dart';

class _FakeTokenStorageService extends TokenStorageService {
  _FakeTokenStorageService(this.accessToken);

  final String? accessToken;

  @override
  Future<String?> readAccessToken() async => accessToken;
}

class _FakeEmergencyCaregiverRepository extends EmergencyCaregiverRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  test(
    'opens medium risk via notifications and critical risk via overlay',
    () async {
      final openedTargets = <RealtimeNotificationOpenTarget>[];
      var notificationsOpened = 0;
      final service = SOSRealtimeAlertService.test(
        riskAlertTargetPresenter: (target) async {
          openedTargets.add(target);
        },
        notificationsNavigator: () async {
          notificationsOpened += 1;
        },
      );
      final runtime = NotificationRuntimeService(
        emergencyAdapter: service,
      );

      await runtime.handleRemoteMessageOpenForTest(<String, dynamic>{
        'type': 'risk_alert',
        'alert_type': 'risk_high',
        'risk_level': 'high',
        'notification_id': 'notif-medium',
      });
      await runtime.handleRemoteMessageOpenForTest(<String, dynamic>{
        'type': 'risk_alert',
        'alert_type': 'risk_critical',
        'risk_level': 'critical',
        'notification_id': 'notif-critical',
      });

      expect(notificationsOpened, 1);
      expect(openedTargets, hasLength(1));
      expect(openedTargets.single.notificationId, 'notif-critical');
    },
  );

  test(
    'foreground critical risk uses full-screen and overlay presenters',
    () async {
      final storage = const FlutterSecureStorage();
      final fullscreenCalls = <String>[];
      final overlayTargets = <RealtimeNotificationOpenTarget>[];
      final service = SOSRealtimeAlertService.test(
        fullScreenAlertPresenter: (item, {required sosId}) async {
          fullscreenCalls.add('${item['id']}:$sosId');
        },
        riskAlertTargetPresenter: (target) async {
          overlayTargets.add(target);
        },
      );
      final runtime = NotificationRuntimeService(
        emergencyAdapter: service,
        storage: storage,
      );

      await runtime.processNotificationEventForTest(<String, dynamic>{
        'id': 'notif-critical-1',
        'alert_type': 'risk_critical',
        'title': 'Critical risk',
        'message': 'Need attention now',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'data': <String, dynamic>{
          'notification_id': 'notif-critical-1',
          'risk_level': 'critical',
          'risk_score_id': '77',
        },
      }, preferFullscreen: true);

      expect(fullscreenCalls, <String>['notif-critical-1:notif-critical-1']);
      expect(overlayTargets, hasLength(1));
      expect(overlayTargets.single.notificationId, 'notif-critical-1');
      expect(overlayTargets.single.riskScoreId, 77);
    },
  );

  test('background risk event stays on missed-alert path', () async {
    final storage = const FlutterSecureStorage();
    final missedCalls = <String>[];
    final overlayTargets = <RealtimeNotificationOpenTarget>[];
      final service = SOSRealtimeAlertService.test(
        missedAlertPresenter: (item, {required sosId}) async {
          missedCalls.add('${item['id']}:$sosId');
        },
        riskAlertTargetPresenter: (target) async {
          overlayTargets.add(target);
        },
      );
      final runtime = NotificationRuntimeService(
        emergencyAdapter: service,
        storage: storage,
      );

      await runtime.processNotificationEventForTest(<String, dynamic>{
        'id': 'notif-medium-1',
        'alert_type': 'risk_high',
        'title': 'Medium risk',
      'message': 'Check soon',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'data': <String, dynamic>{
        'notification_id': 'notif-medium-1',
        'risk_level': 'medium',
      },
    }, preferFullscreen: false);

    expect(missedCalls, <String>['notif-medium-1:notif-medium-1']);
    expect(overlayTargets, isEmpty);
  });

  test(
    'risk event falls back to item id when notification_id is missing',
    () async {
      final storage = const FlutterSecureStorage();
      final missedCalls = <String>[];
      final service = SOSRealtimeAlertService.test(
        missedAlertPresenter: (item, {required sosId}) async {
          missedCalls.add('${item['id']}:$sosId');
        },
      );
      final runtime = NotificationRuntimeService(
        emergencyAdapter: service,
        storage: storage,
      );

      await runtime.processNotificationEventForTest(<String, dynamic>{
        'id': 'notif-medium-2',
        'alert_type': 'risk_high',
        'title': 'Medium risk',
        'message': 'Check soon',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'data': <String, dynamic>{'risk_level': 'medium'},
      }, preferFullscreen: false);

      expect(missedCalls, <String>['notif-medium-2:notif-medium-2']);
    },
  );

  test(
    'android launch payload and auth replay reopen pending critical alert',
    () async {
      final openedTargets = <RealtimeNotificationOpenTarget>[];
      final redirectedTargets = <RealtimeNotificationOpenTarget>[];
      final service = SOSRealtimeAlertService.test(
        tokenStorageService: _FakeTokenStorageService('token-123'),
        emergencyCaregiverRepository: _FakeEmergencyCaregiverRepository(),
        riskAlertTargetPresenter: (target) async {
          openedTargets.add(target);
        },
        criticalAlertAuthRedirector: (target) async {
          redirectedTargets.add(target);
        },
      );
      final runtime = NotificationRuntimeService(
        emergencyAdapter: service,
        tokenStorageService: _FakeTokenStorageService('token-123'),
      );
      final replayTarget = const RealtimeNotificationOpenTarget(
        type: 'risk',
        notificationId: 'notif-replay-1',
        alertType: 'risk_critical',
        riskLevel: 'critical',
        title: 'Critical replay',
        message: 'Return after login',
      );

      await runtime.handleAndroidCriticalAlertLaunchForTest(
        '{"type":"risk","notificationId":"notif-launch-1","alertType":"risk_critical","riskLevel":"critical","riskScoreId":81,"title":"Launch","message":"From native"}',
      );
      await runtime.redirectCriticalAlertToAuthForTest(replayTarget);
      expect(redirectedTargets, <RealtimeNotificationOpenTarget>[replayTarget]);
      expect(runtime.pendingCriticalAlertForTest, replayTarget);

      runtime.setRealtimeEnabledForTest(true);
      await runtime.restorePendingCriticalAlertAfterAuthForTest();

      expect(openedTargets, hasLength(2));
      expect(openedTargets.first.notificationId, 'notif-launch-1');
      expect(openedTargets.last.notificationId, 'notif-replay-1');
      expect(runtime.pendingCriticalAlertForTest, isNull);
    },
  );

  test('recognizes auth failures and extracts backend recipient counts', () {
    final service = SOSRealtimeAlertService.test();

    expect(
      service.looksLikeAuthFailureForTest(Exception('401 unauthorized')),
      isTrue,
    );
    expect(
      service.extractRecipientCountForTest(<String, dynamic>{
        'recipient_count': 4,
      }),
      4,
    );
    expect(
      service.extractRecipientCountForTest(<String, dynamic>{
        'helper_count': '2',
      }),
      2,
    );
    expect(service.extractRecipientCountForTest(const <String, dynamic>{}), 1);
  });
}
