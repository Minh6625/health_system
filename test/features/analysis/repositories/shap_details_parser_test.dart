import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/analysis/domain/entities/risk_report_detail_entity.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';

/// Captures the URL the repository hits + replies with a configurable
/// JSON map. Mirrors the test client used in
/// ``risk_analysis_repository_test.dart``.
class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.handler);

  final Future<Object?> Function(String path, Map<String, dynamic>? query)
      handler;

  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<Object?> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? queryParams,
    int? targetProfileId,
  }) {
    lastPath = path;
    lastQuery = queryParams;
    return handler(path, queryParams);
  }

  @override
  noSuchMethod(Invocation i) => null;
}

Map<String, dynamic> _detailJson({
  Map<String, dynamic>? shapDetails,
  String? modelRequestId,
}) {
  final json = <String, dynamic>{
    'id': 17,
    'risk_type': 'general',
    'score': 18,
    'health_score': 82.0,
    'risk_level': 'low',
    'health_level': 'good',
    'display_status': 'Ổn định',
    'summary': 'OK',
    'timestamp': '2026-04-27T10:00:00+00:00',
    'previous_score': null,
    'trend_7d': [24, 21, 19, 18],
    'breakdown': [],
    'explanation': 'AI nói gì đó',
    'recommendations': <String>[],
    'recommendation_preview': <String>[],
    'top_factors': <Map<String, dynamic>>[],
    'snapshot': {
      'heart_rate': 75, 'spo2': 97,
      'blood_pressure_systolic': 120, 'blood_pressure_diastolic': 80,
      'body_temperature': 36.5, 'hrv_rmssd': 45, 'pulse_pressure': 40,
      'mean_arterial_pressure': 93,
    },
    'confidence': 0.92,
    'is_stale': false,
  };
  if (shapDetails != null) json['shap_details'] = shapDetails;
  if (modelRequestId != null) json['model_request_id'] = modelRequestId;
  return json;
}

void main() {
  group('RiskAnalysisRepository.fetchReportDetail SHAP parsing', () {
    test(
      'patient response (no shap_details / model_request_id) parses with both fields null',
      () async {
        final client = _FakeApiClient((path, query) async => _detailJson());
        final repo = RiskAnalysisRepository(apiClient: client);

        final detail = await repo.fetchReportDetail(17, '42');

        expect(detail.shapDetails, isNull);
        expect(detail.modelRequestId, isNull);
        expect(detail.hasClinicianShapDetails, isFalse);
      },
    );

    test('clinician response (audience=clinician) populates the SHAP fields',
        () async {
      final client = _FakeApiClient(
        (path, query) async => _detailJson(
          shapDetails: {
            'available': true,
            'base_value': 0.05,
            'values': [
              {'feature': 'heart_rate', 'shap_value': 0.42, 'impact': 0.42},
              {'feature': 'spo2', 'shap_value': -0.18, 'impact': 0.18},
            ],
          },
          modelRequestId: 'req-abc-123',
        ),
      );
      final repo = RiskAnalysisRepository(apiClient: client);

      final detail = await repo.fetchReportDetail(
        17, '42', audience: 'clinician',
      );

      expect(client.lastQuery, isNotNull);
      expect(client.lastQuery!['audience'], 'clinician');

      expect(detail.modelRequestId, 'req-abc-123');
      expect(detail.shapDetails, isNotNull);
      expect(detail.shapDetails!.available, isTrue);
      expect(detail.shapDetails!.baseValue, 0.05);
      expect(detail.shapDetails!.values, hasLength(2));
      expect(detail.shapDetails!.values[0].feature, 'heart_rate');
      expect(detail.shapDetails!.values[0].shapValue, 0.42);
      expect(detail.shapDetails!.values[1].isProtective, isTrue);
      expect(detail.hasClinicianShapDetails, isTrue);
    });

    test('available=false response is preserved (rule-based fallback)',
        () async {
      // The backend uses ``available=false`` to signal the row was
      // produced by a fallback inference path that doesn't compute
      // SHAP. The screen must render the empty state, not crash.
      final client = _FakeApiClient(
        (path, query) async => _detailJson(
          shapDetails: {
            'available': false, 'base_value': 0.0, 'values': [],
          },
        ),
      );
      final repo = RiskAnalysisRepository(apiClient: client);

      final detail = await repo.fetchReportDetail(17, '42');

      expect(detail.shapDetails, isNotNull);
      expect(detail.shapDetails!.available, isFalse);
      expect(detail.shapDetails!.hasValues, isFalse);
      // hasClinicianShapDetails is still false → the link is hidden,
      // matching the gating contract.
      expect(detail.hasClinicianShapDetails, isFalse);
    });

    test('non-map shap_details field is treated as null', () async {
      final client = _FakeApiClient(
        (path, query) async => _detailJson(
          // Intentionally invalid: the backend always sends a map,
          // but defend against a future schema change.
          shapDetails: null,
        )..['shap_details'] = ['not', 'a', 'map'],
      );
      final repo = RiskAnalysisRepository(apiClient: client);

      final detail = await repo.fetchReportDetail(17, '42');

      expect(detail.shapDetails, isNull);
    });

    test('contributions with empty feature names are skipped', () async {
      final client = _FakeApiClient(
        (path, query) async => _detailJson(
          shapDetails: {
            'available': true,
            'base_value': 0.0,
            'values': [
              {'feature': 'heart_rate', 'shap_value': 0.5, 'impact': 0.5},
              {'feature': '', 'shap_value': 0.3, 'impact': 0.3},  // skip
              {'feature': null, 'shap_value': 0.2, 'impact': 0.2},  // skip
            ],
          },
        ),
      );
      final repo = RiskAnalysisRepository(apiClient: client);

      final detail = await repo.fetchReportDetail(17, '42');

      expect(detail.shapDetails!.values, hasLength(1));
      expect(detail.shapDetails!.values[0].feature, 'heart_rate');
    });

    test('missing impact falls back to abs(shap_value)', () async {
      final client = _FakeApiClient(
        (path, query) async => _detailJson(
          shapDetails: {
            'available': true,
            'base_value': 0.0,
            'values': [
              {'feature': 'spo2', 'shap_value': -0.18},  // no impact
            ],
          },
        ),
      );
      final repo = RiskAnalysisRepository(apiClient: client);

      final detail = await repo.fetchReportDetail(17, '42');

      expect(detail.shapDetails!.values, hasLength(1));
      expect(detail.shapDetails!.values[0].impact, 0.18);
    });

    test('empty / whitespace-only model_request_id parses as null',
        () async {
      final client = _FakeApiClient(
        (path, query) async => _detailJson(
          modelRequestId: '   ',
        ),
      );
      final repo = RiskAnalysisRepository(apiClient: client);

      final detail = await repo.fetchReportDetail(17, '42');

      // Trimmed empty string is normalised to null so the screen
      // doesn't render an empty "Mã yêu cầu mô hình" row.
      expect(detail.modelRequestId, isNull);
    });

    test('audience kwarg flows through to the request URL', () async {
      final client = _FakeApiClient((path, query) async => _detailJson());
      final repo = RiskAnalysisRepository(apiClient: client);

      // Without audience: query param absent.
      await repo.fetchReportDetail(17, '42');
      expect(client.lastQuery, isNull);

      // With audience: query param present + trimmed.
      await repo.fetchReportDetail(17, '42', audience: '  clinician  ');
      expect(client.lastQuery!['audience'], 'clinician');
    });
  });

  group('ShapWaterfall', () {
    test('totalContribution sums signed values', () {
      const w = ShapWaterfall(
        available: true,
        baseValue: 0,
        values: [
          ShapContribution(feature: 'a', shapValue: 0.5, impact: 0.5),
          ShapContribution(feature: 'b', shapValue: -0.2, impact: 0.2),
        ],
      );
      expect(w.totalContribution, closeTo(0.3, 1e-9));
    });

    test('hasValues is false when available=false', () {
      const w = ShapWaterfall(
        available: false,
        baseValue: 0,
        values: [
          ShapContribution(feature: 'a', shapValue: 0.5, impact: 0.5),
        ],
      );
      expect(w.hasValues, isFalse);
    });

    test('isProtective is true for negative shap values', () {
      const positive = ShapContribution(
        feature: 'a', shapValue: 0.4, impact: 0.4,
      );
      const negative = ShapContribution(
        feature: 'b', shapValue: -0.4, impact: 0.4,
      );
      expect(positive.isProtective, isFalse);
      expect(negative.isProtective, isTrue);
    });
  });
}
