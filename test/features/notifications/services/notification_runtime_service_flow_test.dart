import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/notifications/models/notification_open_target.dart';
import 'package:healthguard/features/notifications/services/notification_runtime_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const MethodChannel _localNotificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const MethodChannel _androidCriticalAlertTestChannel = MethodChannel(
  'healthguard/test/critical_alert',
);

class _FakeNotificationEmergencyAdapter implements NotificationEmergencyAdapter {
  final List<String> notificationsOpened = <String>[];
  final List<String> openedSosIds = <String>[];
  final List<NotificationOpenTarget> openedTargets = <NotificationOpenTarget>[];
  final List<NotificationOpenTarget> redirectedTargets =
      <NotificationOpenTarget>[];
  final List<int> openedFallEventIds = <int>[];

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

  @override
  Future<void> presentFallAlert({
    required int fallEventId,
    String? fallEventUuid,
    double confidence = 0.0,
  }) async {
    openedFallEventIds.add(fallEventId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_localNotificationsChannel, (
      MethodCall call,
    ) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'requestNotificationsPermission':
        case 'requestFullScreenIntentPermission':
          return true;
        case 'createNotificationChannel':
          return null;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(_androidCriticalAlertTestChannel, (
      MethodCall call,
    ) async {
      if (call.method == 'consumePendingCriticalAlertLaunch') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_localNotificationsChannel, null);
    messenger.setMockMethodCallHandler(_androidCriticalAlertTestChannel, null);
  });

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

  test(
    'replays deferred authenticated state after initialize',
    () async {
      final requests = <String>[];
      final apiClient = ApiClient.test(
        baseUrlOverride: 'http://localhost/api/v1/mobile',
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');

          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode({
                'notifications': const <Map<String, dynamic>>[],
                'total_count': 0,
                'unread_count': 0,
                'limit': 50,
                'offset': 0,
              }),
              200,
            );
          }

          return http.Response('{}', 200);
        }),
      );
      final service = NotificationRuntimeService(
        emergencyAdapter: _FakeNotificationEmergencyAdapter(),
        apiClient: apiClient,
        androidCriticalAlertBridge: _androidCriticalAlertTestChannel,
      );

      await service.onAuthStateChanged(isAuthenticated: true);
      await service.initialize();
      await service.dispose();

      expect(requests, contains('GET /api/v1/mobile/notifications'));
    },
  );
}
