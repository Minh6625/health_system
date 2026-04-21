import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _defaultE2EApiUrl = String.fromEnvironment(
  'E2E_API_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1/mobile',
);
const String _defaultMockDeviceFlag = String.fromEnvironment(
  'E2E_MOCK_DEVICE',
  defaultValue: 'false',
);

String get e2eApiUrl => _defaultE2EApiUrl;

Future<void> loadE2ETestConfig({String? apiUrl, bool? mockDevice}) async {
  final resolvedMockDevice =
      mockDevice?.toString() ?? _defaultMockDeviceFlag.toLowerCase();
  dotenv.testLoad(
    fileInput:
        'API_URL=${apiUrl ?? _defaultE2EApiUrl}\nMOCK_DEVICE=$resolvedMockDevice',
  );
}
