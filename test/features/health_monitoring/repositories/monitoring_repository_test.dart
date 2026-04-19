import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/health_monitoring/repositories/monitoring_repository.dart';

class _GetCall {
  const _GetCall({
    required this.path,
    required this.requiresAuth,
    required this.queryParams,
    required this.targetProfileId,
  });

  final String path;
  final bool requiresAuth;
  final Map<String, dynamic>? queryParams;
  final int? targetProfileId;
}

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this._handler);

  final Future<dynamic> Function(_GetCall call) _handler;
  final List<_GetCall> calls = [];

  @override
  int? targetProfileId;

  @override
  String get baseUrl => 'http://localhost';

  @override
  Future<dynamic> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? queryParams,
    int? targetProfileId,
  }) {
    final call = _GetCall(
      path: path,
      requiresAuth: requiresAuth,
      queryParams: queryParams,
      targetProfileId: targetProfileId,
    );
    calls.add(call);
    return _handler(call);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'MonitoringRepository forwards linked profile id to latest vitals endpoint',
    () async {
      final client = _FakeApiClient((call) async {
        return {
          'heart_rate': 72,
          'spo2': 98,
          'temperature': 36.7,
          'respiratory_rate': 16,
          'blood_pressure_sys': 118,
          'blood_pressure_dia': 76,
          'timestamp': '2026-04-19T08:00:00Z',
          'is_stale': false,
        };
      });
      final repository = MonitoringRepository(client: client);

      final vitals = await repository.getLatestVitals(profileId: '42');

      expect(vitals.heartRate, 72);
      expect(client.calls.single.path, ApiEndpoints.vitalsLatest);
      expect(client.calls.single.targetProfileId, 42);
    },
  );

  test(
    'MonitoringRepository keeps self profile requests on current user context',
    () async {
      final client = _FakeApiClient((call) async {
        return {
          'heart_rate': 72,
          'spo2': 98,
          'temperature': 36.7,
          'respiratory_rate': 16,
          'blood_pressure_sys': 118,
          'blood_pressure_dia': 76,
          'timestamp': '2026-04-19T08:00:00Z',
          'is_stale': false,
        };
      });
      final repository = MonitoringRepository(client: client);

      await repository.getLatestVitals();

      expect(client.calls.single.targetProfileId, isNull);
    },
  );
}
