import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/notifications/screens/notifications_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  testWidgets(
    'loads notifications, marks them read, and opens SOS route',
    (tester) async {
      final calls = <String>[];
      final client = ApiClient.test(
        baseUrlOverride: 'http://localhost/api/v1/mobile',
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');

          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode({
                'notifications': [
                  {
                    'id': 91,
                    'alert_type': 'sos',
                    'severity': 'critical',
                    'title': 'SOS',
                    'message': 'Need help',
                    'created_at': '2026-04-22T00:00:00Z',
                    'is_read': false,
                    'data': {'sos_id': 'sos-91'},
                  },
                ],
                'total_count': 1,
                'unread_count': 1,
                'limit': 10,
                'offset': 0,
              }),
              200,
            );
          }

          if (request.method == 'PUT' &&
              request.url.path.endsWith('/notifications/91/read')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Notification marked as read',
                'notification_id': 91,
                'read_at': '2026-04-22T00:01:00Z',
              }),
              200,
            );
          }

          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: <String, WidgetBuilder>{
            AppRouter.emergencySosDetail: (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>? ??
                  const <String, dynamic>{};
              return Scaffold(
                body: Text('SOS detail ${args['sosId'] ?? '<missing>'}'),
              );
            },
          },
          home: NotificationsScreen(apiClient: client),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SOS'), findsOneWidget);
      expect(find.textContaining('Chưa đọc: 1'), findsOneWidget);

      await tester.tap(find.text('SOS'));
      await tester.pumpAndSettle();

      expect(calls, contains('PUT /api/v1/mobile/notifications/91/read'));
      expect(find.text('SOS detail sos-91'), findsOneWidget);
    },
  );

  testWidgets(
    'filters notifications by search query and opens detail payload',
    (tester) async {
      final client = ApiClient.test(
        baseUrlOverride: 'http://localhost/api/v1/mobile',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications/11')) {
            return http.Response(
              jsonEncode({
                'id': 11,
                'alert_type': 'risk_high',
                'severity': 'medium',
                'title': 'Risk warning',
                'message': 'Check vitals now',
                'created_at': '2026-04-22T00:00:00Z',
                'is_read': true,
                'read_at': '2026-04-22T00:01:00Z',
                'data': {'risk_level': 'medium', 'risk_score_id': 901},
              }),
              200,
            );
          }

          if (request.method == 'PUT' &&
              request.url.path.endsWith('/notifications/11/read')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Notification marked as read',
                'notification_id': 11,
                'read_at': '2026-04-22T00:01:00Z',
              }),
              200,
            );
          }

          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode({
                'notifications': [
                  {
                    'id': 11,
                    'alert_type': 'risk_high',
                    'severity': 'medium',
                    'title': 'Risk warning',
                    'message': 'Check vitals now',
                    'created_at': '2026-04-22T00:00:00Z',
                    'is_read': false,
                    'data': {'risk_level': 'medium', 'risk_score_id': 901},
                  },
                  {
                    'id': 12,
                    'alert_type': 'medication_missed',
                    'severity': 'low',
                    'title': 'Medication reminder',
                    'message': 'Remember evening medication',
                    'created_at': '2026-04-21T23:00:00Z',
                    'is_read': false,
                    'data': {'duration_minutes': 30},
                  },
                ],
                'total_count': 2,
                'unread_count': 2,
                'limit': 10,
                'offset': 0,
              }),
              200,
            );
          }

          return http.Response('{}', 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(home: NotificationsScreen(apiClient: client)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medication reminder'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'risk');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Risk warning'), findsOneWidget);
      expect(find.text('Medication reminder'), findsNothing);

      await tester.tap(find.text('Risk warning'));
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải chi tiết thông báo'), findsNothing);
      expect(find.textContaining('Risk warning'), findsWidgets);
      expect(find.text('Đọc lúc'), findsOneWidget);
    },
  );

  testWidgets(
    'uses the latest injected api client after rebuild',
    (tester) async {
      final initialClient = ApiClient.test(
        baseUrlOverride: 'http://localhost/api/v1/mobile',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode({
                'notifications': [
                  {
                    'id': 21,
                    'alert_type': 'general',
                    'severity': 'low',
                    'title': 'Alpha notice',
                    'message': 'Initial client payload',
                    'created_at': '2026-04-22T00:00:00Z',
                    'is_read': false,
                    'data': const <String, dynamic>{},
                  },
                ],
                'total_count': 1,
                'unread_count': 1,
                'limit': 10,
                'offset': 0,
              }),
              200,
            );
          }

          return http.Response('{}', 200);
        }),
      );

      final swappedClient = ApiClient.test(
        baseUrlOverride: 'http://localhost/api/v1/mobile',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/notifications')) {
            return http.Response(
              jsonEncode({
                'notifications': [
                  {
                    'id': 22,
                    'alert_type': 'general',
                    'severity': 'low',
                    'title': 'Beta notice',
                    'message': 'Swapped client payload',
                    'created_at': '2026-04-22T00:05:00Z',
                    'is_read': false,
                    'data': const <String, dynamic>{},
                  },
                ],
                'total_count': 1,
                'unread_count': 1,
                'limit': 10,
                'offset': 0,
              }),
              200,
            );
          }

          return http.Response('{}', 200);
        }),
      );

      final clientNotifier = ValueNotifier<ApiClient>(initialClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<ApiClient>(
            valueListenable: clientNotifier,
            builder: (context, client, _) {
              return NotificationsScreen(apiClient: client);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha notice'), findsOneWidget);

      clientNotifier.value = swappedClient;
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Beta notice'), findsOneWidget);
      expect(find.text('Alpha notice'), findsNothing);
    },
  );
}
