import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/home/repositories/home_dashboard_repository.dart';

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
  group('HomeDashboardRepository', () {
    test(
      'passes linked profile through targetProfileId on dashboard endpoints',
      () async {
        final client = _FakeApiClient((call) async {
          switch (call.path) {
            case '/metrics/vital-signs/latest':
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
            case '/metrics/health-report':
              return {
                'latest_risk_score': 18,
                'health_score': 82,
                'health_level': 'good',
                'health_summary': 'Ổn định.',
                'risk_level': 'low',
                'risk_type': 'general',
                'confidence': 0.92,
                'is_stale': false,
                'vitals_24h_avg': {'avg_hr': 72},
              };
            case '/metrics/sleep/latest':
              return {'quality_score': 84, 'in_bed_minutes': 430};
          }
          throw StateError('Unexpected path ${call.path}');
        });
        final repository = HomeDashboardRepository(apiClient: client);

        await repository.getLatestVitalSigns(profileId: '42');
        await repository.getHealthReport(profileId: '42');
        await repository.getLatestSleepSession(profileId: '42');

        expect(client.calls, hasLength(3));
        expect(
          client.calls.map((call) => call.targetProfileId),
          everyElement(42),
        );
      },
    );

    test(
      'keeps self-profile requests free of targetProfileId header forwarding',
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
        final repository = HomeDashboardRepository(apiClient: client);

        await repository.getLatestVitalSigns();

        expect(client.calls.single.targetProfileId, isNull);
      },
    );

    test(
      'throws when /analysis/risk-reports no longer returns canonical list shape',
      () async {
        final client = _FakeApiClient((call) async {
          return {
            'items': [
              {
                'id': 1,
                'risk_type': 'general',
                'score': 20,
                'risk_level': 'low',
                'timestamp': '2026-04-19T08:00:00Z',
              },
            ],
          };
        });
        final repository = HomeDashboardRepository(apiClient: client);

        expect(
          () => repository.getRiskReports(profileId: '42'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
