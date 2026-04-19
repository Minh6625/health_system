import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';

void main() {
  group('EmergencyCaregiverRepository', () {
    late HttpServer server;
    late Completer<Map<String, dynamic>> requestCapture;

    setUpAll(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requestCapture.complete({
          'method': request.method,
          'path': request.uri.path,
          'body': body,
        });

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'recipient_count': 3, 'status': 'ok'}),
        );
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    setUp(() {
      requestCapture = Completer<Map<String, dynamic>>();
      dotenv.testLoad(
        fileInput: 'API_URL=http://127.0.0.1:${server.port}/api/v1/mobile',
      );
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'access_token': 'test-token',
      });
    });

    test('posts risk responses to the risk-response endpoint', () async {
      final repository = EmergencyCaregiverRepository();

      final response = await repository.respondToRiskNotification(
        notificationId: 'notif-42',
        responseType: 'help_requested',
        source: 'overlay',
        riskScoreId: 99,
      );
      final request = await requestCapture.future;

      expect(request['method'], 'POST');
      expect(request['path'], '/api/v1/mobile/risk/alerts/notif-42/respond');
      expect(jsonDecode(request['body'] as String) as Map<String, dynamic>, {
        'risk_score_id': 99,
        'action': 'help_requested',
        'source': 'overlay',
      });
      expect(response['recipient_count'], 3);
      expect(response['status'], 'ok');
    });
  });
}
