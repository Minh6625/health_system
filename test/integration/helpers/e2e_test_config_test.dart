import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/helpers/e2e_test_config.dart';

void main() {
  group('resolveE2EApiUrl', () {
    test('prefers explicit apiUrl override', () {
      final result = resolveE2EApiUrl(
        apiUrl: 'http://192.168.1.102:8000/api/v1/mobile',
        e2eApiUrl:
            'http://192.168.1.103:8000/api/v1/mobile',
        appApiUrl:
            'http://192.168.1.104:8000/api/v1/mobile',
      );

      expect(result, 'http://192.168.1.102:8000/api/v1/mobile');
    });

    test('falls back to E2E_API_URL define when explicit apiUrl is absent', () {
      final result = resolveE2EApiUrl(
        e2eApiUrl:
            'http://192.168.1.103:8000/api/v1/mobile',
        appApiUrl:
            'http://192.168.1.104:8000/api/v1/mobile',
      );

      expect(result, 'http://192.168.1.103:8000/api/v1/mobile');
    });

    test('falls back to app API_URL when no E2E override exists', () {
      final result = resolveE2EApiUrl(
        appApiUrl:
            'http://192.168.1.104:8000/api/v1/mobile',
      );

      expect(result, 'http://192.168.1.104:8000/api/v1/mobile');
    });
  });

  group('parseApiUrlFromEnvContents', () {
    test('reads API_URL from dotenv contents', () {
      const envContents = '''
# Backend API
API_URL=http://192.168.1.105:8000/api/v1/mobile
MOCK_DEVICE=false
''';

      expect(
        parseApiUrlFromEnvContents(envContents),
        'http://192.168.1.105:8000/api/v1/mobile',
      );
    });
  });
}
