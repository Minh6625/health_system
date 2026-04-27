import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';

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
  group('RiskAnalysisRepository', () {
    test(
      'forwards linked profile through targetProfileId on latest report',
      () async {
        final client = _FakeApiClient((call) async {
          return [
            {
              'id': 9,
              'risk_type': 'general',
              'risk_score': 18.0,
              'score': 18.0,
              'risk_level': 'low',
              'display_status': 'On dinh',
              'summary': 'On dinh.',
              'timestamp': '2026-04-19T08:00:00Z',
              'previous_score': null,
              'trend_7d': [24, 21, 19, 18],
              'top_factors': [
                {'key': 'heart_rate', 'label': 'Nhip tim'},
              ],
              'recommendation_preview': ['Tiep tuc theo doi dinh ky.'],
              'confidence': 0.92,
              'is_stale': false,
            },
          ];
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        final report = await repository.fetchLatestReport('42');

        expect(report.reportId, 9);
        expect(report.displayStatus, 'On dinh');
        expect(client.calls.single.path, '/analysis/risk-reports');
        expect(client.calls.single.queryParams, {'limit': 1});
        expect(client.calls.single.targetProfileId, 42);
      },
    );

    test(
      'keeps self profile latest requests on current user context',
      () async {
        final client = _FakeApiClient((call) async {
          return [
            {
              'id': 9,
              'risk_type': 'general',
              'risk_score': 18.0,
              'score': 18.0,
              'risk_level': 'low',
              'display_status': 'On dinh',
              'summary': 'On dinh.',
              'timestamp': '2026-04-19T08:00:00Z',
              'previous_score': null,
              'trend_7d': [24, 21, 19, 18],
              'top_factors': const [],
              'recommendation_preview': const [],
              'confidence': 0.92,
              'is_stale': false,
            },
          ];
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        await repository.fetchLatestReport(null);

        expect(client.calls.single.targetProfileId, isNull);
      },
    );

    test(
      'throws when latest reports endpoint stops returning canonical list shape',
      () async {
        final client = _FakeApiClient((call) async {
          return {
            'items': [
              {
                'id': 1,
                'risk_type': 'general',
                'risk_score': 20,
                'risk_level': 'low',
                'timestamp': '2026-04-19T08:00:00Z',
              },
            ],
          };
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        expect(
          () => repository.fetchLatestReport('42'),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'fetchLatestReport parses canonical-only payload (no deprecated risk_score)',
      () async {
        // Phase 1 contract: backend may eventually drop the deprecated
        // `risk_score` alias (Phase 6). The mobile parser must already prefer
        // `score`, so a payload missing `risk_score` must still parse correctly.
        final client = _FakeApiClient((call) async {
          return [
            {
              'id': 11,
              'risk_type': 'general',
              // Note: no `risk_score` key — only canonical `score`.
              'score': 73.0,
              'risk_level': 'medium',
              'display_status': 'Theo doi',
              'summary': 'Theo doi.',
              'timestamp': '2026-04-21T08:00:00Z',
              'previous_score': 70,
              'trend_7d': [70, 71, 72, 73],
              'top_factors': const [],
              'recommendation_preview': const [],
              'confidence': 0.81,
              'is_stale': false,
            },
          ];
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        final report = await repository.fetchLatestReport('42');

        expect(report.score, 73);
        expect(report.displayStatus, 'Theo doi');
      },
    );

    test(
      'fetchReportDetail parses canonical-only payload (no risk_score, no xai_explanation)',
      () async {
        final client = _FakeApiClient((call) async {
          return {
            'id': 11,
            'risk_type': 'general',
            // Canonical only: no `risk_score`, no `xai_explanation`.
            'score': 73.0,
            'health_score': 27.0,
            'risk_level': 'medium',
            'display_status': 'Theo doi',
            'summary': 'Theo doi.',
            'timestamp': '2026-04-21T08:00:00Z',
            'previous_score': 70,
            'trend_7d': [70, 71, 72, 73],
            'explanation': 'Nhip tim hoi cao.',
            'breakdown': const [],
            'recommendations': const ['Nghi ngoi.'],
            'recommendation_preview': const ['Nghi ngoi.'],
            'top_factors': const [],
            'snapshot': const {
              'heart_rate': 96,
              'spo2': 96,
              'sys_bp': 122,
              'dia_bp': 78,
              'body_temp': 36.7,
              'hrv': 36,
              'map_val': 92,
            },
            'confidence': 0.78,
            'is_stale': false,
          };
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        final detail = await repository.fetchReportDetail(11, '42');

        expect(detail.score, 73);
        expect(detail.healthScore, 27.0);
        expect(detail.xaiExplanation, 'Nhip tim hoi cao.');
      },
    );

    test(
      'fetchHistory parses canonical-only payload (no risk_score on items)',
      () async {
        final client = _FakeApiClient((call) async {
          return {
            'range': '7d',
            'summary': const {
              'average_score': 72.5,
              'highest_score': 75.0,
              'lowest_score': 70.0,
              'delta_vs_previous_period': 1.5,
              'trend_points': [70, 71, 72, 73, 74, 75, 73],
            },
            'items': [
              {
                'report_id': 11,
                // Canonical only.
                'score': 73.0,
                'health_score': 27.0,
                'risk_level': 'medium',
                'display_status': 'Theo doi',
                'analyzed_at': '2026-04-21T08:00:00Z',
                'reason_preview': 'Nhip tim hoi cao.',
                'is_stale': false,
              },
            ],
            'page': 1,
            'limit': 20,
            'has_more': false,
          };
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        final history = await repository.fetchHistory(profileId: '42');

        expect(history.items.single.score, 73);
        expect(history.items.single.healthScore, 27.0);
      },
    );

    test(
      'mobile parser prefers canonical score when both keys are present and disagree',
      () async {
        // Defensive: if a buggy backend ever emits divergent values for the
        // deprecated and canonical keys, the parser must trust the canonical
        // value. This locks in the Phase 1 ordering.
        final client = _FakeApiClient((call) async {
          return [
            {
              'id': 12,
              'risk_type': 'general',
              'score': 50.0, // canonical — should win
              'risk_score': 99.0, // deprecated — must be ignored
              'risk_level': 'medium',
              'display_status': 'Theo doi',
              'summary': '',
              'timestamp': '2026-04-21T08:00:00Z',
              'top_factors': const [],
              'recommendation_preview': const [],
              'confidence': 0.5,
              'is_stale': false,
            },
          ];
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        final report = await repository.fetchLatestReport('42');

        expect(report.score, 50, reason: 'canonical `score` must win');
      },
    );

    test(
      'parses canonical detail and history payloads with doubles and stale fields',
      () async {
        final client = _FakeApiClient((call) async {
          switch (call.path) {
            case '/analysis/risk-reports/9':
              return {
                'id': 9,
                'risk_type': 'general',
                'risk_score': 82.5,
                'score': 82.5,
                'health_score': 17.5,
                'risk_level': 'critical',
                'display_status': 'Nguy hiem',
                'summary': 'Can theo doi sat.',
                'timestamp': '2026-04-19T08:00:00Z',
                'previous_score': 61.0,
                'trend_7d': [55, 58, 61, 67, 72, 79, 83],
                'xai_explanation': 'Nhip tim va SpO2 dang xau di.',
                'breakdown': [
                  {
                    'key': 'heart_rate',
                    'label': 'Nhip tim',
                    'contribution_score': 0.62,
                    'impact_level': 'high',
                    'value': '108',
                    'unit': 'bpm',
                    'route_target': 'vital_hr',
                  },
                ],
                'recommendations': ['Nghi ngoi va do lai.'],
                'recommendation_preview': ['Nghi ngoi va do lai.'],
                'top_factors': [
                  {'key': 'heart_rate', 'label': 'Nhip tim'},
                ],
                'snapshot': {
                  'heart_rate': 108,
                  'spo2': 93,
                  'sys_bp': 138,
                  'dia_bp': 84,
                  'body_temp': 36.9,
                  'hrv': 28,
                  'map_val': 102,
                },
                'confidence': 0.75,
                'is_stale': true,
              };
            case '/analysis/risk-history':
              return {
                'range': '30d',
                'summary': {
                  'average_score': 46.5,
                  'highest_score': 82.5,
                  'lowest_score': 21.0,
                  'delta_vs_previous_period': 5.5,
                  'trend_points': [35, 41, 39, 46, 52, 61, 83],
                },
                'items': [
                  {
                    'report_id': 9,
                    'risk_score': 82.5,
                    'score': 82.5,
                    'health_score': 17.5,
                    'risk_level': 'critical',
                    'display_status': 'Nguy hiem',
                    'analyzed_at': '2026-04-19T08:00:00Z',
                    'reason_preview': 'Chi so canh bao dang tang.',
                    'is_stale': true,
                  },
                ],
                'page': 2,
                'limit': 10,
                'has_more': true,
              };
          }
          throw StateError('Unexpected path ${call.path}');
        });
        final repository = RiskAnalysisRepository(apiClient: client);

        final detail = await repository.fetchReportDetail(9, '42');
        final history = await repository.fetchHistory(
          profileId: '42',
          range: '30d',
          page: 2,
          limit: 10,
        );

        expect(detail.healthScore, 17.5);
        expect(detail.displayStatus, 'Nguy hiem');
        expect(detail.previousScore, 61);
        expect(
          detail.breakdown.single.contributionScore,
          closeTo(0.62, 0.0001),
        );
        expect(detail.isStale, isTrue);
        expect(history.range, '30d');
        expect(history.summary.averageScore, 46.5);
        expect(history.summary.deltaVsPreviousPeriod, 5.5);
        expect(history.items.single.displayStatus, 'Nguy hiem');
        expect(history.items.single.healthScore, 17.5);
        expect(history.items.single.isStale, isTrue);
        expect(client.calls.last.queryParams, {
          'range': '30d',
          'page': 2,
          'limit': 10,
        });
        expect(client.calls.last.targetProfileId, 42);
      },
    );
  });
}
