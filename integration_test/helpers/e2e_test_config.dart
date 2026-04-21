import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String _defaultE2EApiUrl = String.fromEnvironment(
  'E2E_API_URL',
  defaultValue: '',
);
const String _defaultMockDeviceFlag = String.fromEnvironment(
  'E2E_MOCK_DEVICE',
  defaultValue: 'false',
);
const String _fallbackApiUrl = 'http://10.0.2.2:8000/api/v1/mobile';

String get e2eApiUrl => _defaultE2EApiUrl;

@visibleForTesting
String? parseApiUrlFromEnvContents(String envContents) {
  for (final rawLine in envContents.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (line.startsWith('API_URL=')) {
      final value = line.substring('API_URL='.length).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  }
  return null;
}

@visibleForTesting
String resolveE2EApiUrl({
  String? apiUrl,
  String? e2eApiUrl,
  String? appApiUrl,
}) {
  final candidates = <String?>[apiUrl, e2eApiUrl, appApiUrl];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return _fallbackApiUrl;
}

Future<String?> _readApiUrlFromAppEnv() async {
  const isProduction = bool.fromEnvironment('dart.vm.product');
  final envFile = isProduction ? '.env.prod' : '.env.dev';
  try {
    final envContents = await rootBundle.loadString(envFile);
    return parseApiUrlFromEnvContents(envContents);
  } catch (_) {
    return null;
  }
}

Future<void> loadE2ETestConfig({String? apiUrl, bool? mockDevice}) async {
  final resolvedMockDevice =
      mockDevice?.toString() ?? _defaultMockDeviceFlag.toLowerCase();
  final appApiUrl = await _readApiUrlFromAppEnv();
  final resolvedApiUrl = resolveE2EApiUrl(
    apiUrl: apiUrl,
    e2eApiUrl: _defaultE2EApiUrl,
    appApiUrl: appApiUrl,
  );
  dotenv.testLoad(
    fileInput:
        'API_URL=$resolvedApiUrl\nMOCK_DEVICE=$resolvedMockDevice',
  );
}
