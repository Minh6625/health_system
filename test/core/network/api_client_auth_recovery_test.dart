import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AuthSessionService sessionService;

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    sessionService = AuthSessionService();
  });

  test('retries a protected request after refresh succeeds', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');

      if (request.url.path.endsWith('/protected')) {
        final authHeader = request.headers['Authorization'];
        if (authHeader == 'Bearer stale-access-token') {
          return http.Response('{"detail":"expired"}', 401);
        }
        if (authHeader == 'Bearer fresh-access-token') {
          return http.Response('{"ok":true}', 200);
        }
      }

      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'message': 'Token đã được làm mới',
              'access_token': 'fresh-access-token',
              'user': {
                'user_id': 7,
                'email': 'elder@example.com',
                'full_name': 'Nguyen Van A',
                'role': 'patient',
              },
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response('{"detail":"unexpected"}', 500);
    });

    await const FlutterSecureStorage().write(
      key: 'access_token',
      value: 'stale-access-token',
    );
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'refresh-token',
    );
    await const FlutterSecureStorage().write(
      key: 'user_session',
      value:
          '{"user_id":7,"email":"elder@example.com","full_name":"Nguyen Van A","role":"patient"}',
    );

    final apiClient = ApiClient.test(
      httpClient: client,
      sessionService: sessionService,
      baseUrlOverride: 'http://localhost/api/v1/mobile',
    );

    final response = await apiClient.get('/protected');

    expect(response, {'ok': true});
    expect(requests, [
      'GET /api/v1/mobile/protected',
      'POST /api/v1/mobile/auth/refresh',
      'GET /api/v1/mobile/protected',
    ]);
    expect(
      await const FlutterSecureStorage().read(key: 'access_token'),
      'fresh-access-token',
    );
  });

  test('clears session and throws when refresh fails', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/protected')) {
        return http.Response('{"detail":"expired"}', 401);
      }

      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response('{"detail":"invalid refresh"}', 401);
      }

      return http.Response('{"detail":"unexpected"}', 500);
    });

    await const FlutterSecureStorage().write(
      key: 'access_token',
      value: 'stale-access-token',
    );
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'bad-refresh-token',
    );
    await const FlutterSecureStorage().write(
      key: 'user_session',
      value:
          '{"user_id":7,"email":"elder@example.com","full_name":"Nguyen Van A","role":"patient"}',
    );

    final apiClient = ApiClient.test(
      httpClient: client,
      sessionService: sessionService,
      baseUrlOverride: 'http://localhost/api/v1/mobile',
    );

    await expectLater(
      apiClient.get('/protected'),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(
      await const FlutterSecureStorage().read(key: 'access_token'),
      isNull,
    );
    expect(
      await const FlutterSecureStorage().read(key: 'refresh_token'),
      isNull,
    );
    expect(
      await const FlutterSecureStorage().read(key: 'user_session'),
      isNull,
    );
  });

  test('refreshes only once for concurrent unauthorized requests', () async {
    var refreshCalls = 0;
    var freshProtectedCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/protected')) {
        final authHeader = request.headers['Authorization'];
        if (authHeader == 'Bearer stale-access-token') {
          return http.Response('{"detail":"expired"}', 401);
        }
        if (authHeader == 'Bearer fresh-access-token') {
          freshProtectedCalls += 1;
          return http.Response('{"ok":true}', 200);
        }
      }

      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'success': true,
              'message': 'Token refreshed',
              'access_token': 'fresh-access-token',
              'user': {
                'user_id': 7,
                'email': 'elder@example.com',
                'full_name': 'Nguyen Van A',
                'role': 'patient',
              },
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response('{"detail":"unexpected"}', 500);
    });

    await const FlutterSecureStorage().write(
      key: 'access_token',
      value: 'stale-access-token',
    );
    await const FlutterSecureStorage().write(
      key: 'refresh_token',
      value: 'refresh-token',
    );
    await const FlutterSecureStorage().write(
      key: 'user_session',
      value:
          '{"user_id":7,"email":"elder@example.com","full_name":"Nguyen Van A","role":"patient"}',
    );

    final apiClient = ApiClient.test(
      httpClient: client,
      sessionService: sessionService,
      baseUrlOverride: 'http://localhost/api/v1/mobile',
    );

    final responses = await Future.wait([
      apiClient.get('/protected'),
      apiClient.get('/protected'),
    ]);

    expect(responses, [
      {'ok': true},
      {'ok': true},
    ]);
    expect(refreshCalls, 1);
    expect(freshProtectedCalls, 2);
  });
}
