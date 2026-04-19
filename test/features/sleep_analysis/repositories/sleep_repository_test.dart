import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';

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

Map<String, dynamic> _sleepJson({
  required String sessionId,
  required DateTime sleepDate,
  required DateTime startTime,
  required DateTime endTime,
}) {
  return {
    'session_id': sessionId,
    'sleep_date':
        '${sleepDate.year.toString().padLeft(4, '0')}-${sleepDate.month.toString().padLeft(2, '0')}-${sleepDate.day.toString().padLeft(2, '0')}',
    'start_time': startTime.toUtc().toIso8601String(),
    'end_time': endTime.toUtc().toIso8601String(),
    'in_bed_minutes': 420,
    'sleep_minutes': 380,
    'awake_minutes': 40,
    'efficiency_ratio': 0.9,
    'quality_score': 78,
    'quality_label': 'GOOD',
    'wake_count': 1,
    'phases': {'light': 210, 'deep': 90, 'rem': 80, 'awake': 40},
  };
}

void main() {
  group('SleepRepositoryImpl', () {
    test(
      'getLatestSleep keeps self profile requests free of patient query params',
      () async {
        final client = _FakeApiClient((call) async {
          return _sleepJson(
            sessionId: 'latest-self',
            sleepDate: DateTime(2026, 4, 17),
            startTime: DateTime(2026, 4, 16, 22, 30),
            endTime: DateTime(2026, 4, 17, 5, 30),
          );
        });
        final repository = SleepRepositoryImpl(client: client);

        final session = await repository.getLatestSleep();

        expect(session, isNotNull);
        expect(client.calls.single.path, ApiEndpoints.latestSleep);
        expect(client.calls.single.queryParams, isNull);
        expect(client.calls.single.targetProfileId, isNull);
      },
    );

    test(
      'getLatestSleep maps linked profile id to X-Target-Profile-Id path argument',
      () async {
        final client = _FakeApiClient((call) async {
          return _sleepJson(
            sessionId: 'latest-linked',
            sleepDate: DateTime(2026, 4, 17),
            startTime: DateTime(2026, 4, 16, 22, 30),
            endTime: DateTime(2026, 4, 17, 5, 30),
          );
        });
        final repository = SleepRepositoryImpl(client: client);

        await repository.getLatestSleep(patientId: '42');

        expect(client.calls.single.targetProfileId, 42);
      },
    );

    test(
      'getSleepHistory uses from_date and to_date without patient_id query params',
      () async {
        final client = _FakeApiClient((call) async {
          return {
            'data': [
              _sleepJson(
                sessionId: 'history-1',
                sleepDate: DateTime(2026, 4, 15),
                startTime: DateTime(2026, 4, 14, 22, 30),
                endTime: DateTime(2026, 4, 15, 5, 30),
              ),
            ],
          };
        });
        final repository = SleepRepositoryImpl(client: client);

        final history = await repository.getSleepHistory(
          from: DateTime(2026, 4, 14, 23, 59),
          to: DateTime(2026, 4, 16, 8, 0),
          patientId: '88',
        );

        expect(history, hasLength(1));
        expect(client.calls.single.path, ApiEndpoints.sleepHistory);
        expect(client.calls.single.queryParams, {
          'from_date': '2026-04-14',
          'to_date': '2026-04-16',
        });
        expect(
          client.calls.single.queryParams!.containsKey('patient_id'),
          isFalse,
        );
        expect(client.calls.single.targetProfileId, 88);
      },
    );

    test(
      'getSessionByDate selects by canonical sleep_date instead of timestamp window',
      () async {
        final reportDate = DateTime(2026, 4, 16);
        final client = _FakeApiClient((call) async {
          expect(call.queryParams, {
            'from_date': '2026-04-16',
            'to_date': '2026-04-16',
          });
          return {
            'data': [
              _sleepJson(
                sessionId: 'match',
                sleepDate: reportDate,
                startTime: DateTime(2026, 4, 15, 23, 0),
                endTime: DateTime(2026, 4, 16, 6, 30),
              ),
              _sleepJson(
                sessionId: 'other',
                sleepDate: DateTime(2026, 4, 15),
                startTime: DateTime(2026, 4, 14, 23, 0),
                endTime: DateTime(2026, 4, 15, 6, 30),
              ),
            ],
          };
        });
        final repository = SleepRepositoryImpl(client: client);

        final session = await repository.getSessionByDate(
          reportDate,
          patientId: '12',
        );

        expect(session?.sessionId, 'match');
        expect(client.calls.single.targetProfileId, 12);
      },
    );
  });
}
