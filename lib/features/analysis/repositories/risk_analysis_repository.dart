import 'package:healthguard/core/network/api_client.dart';
import '../domain/entities/risk_history_entity.dart';
import '../domain/entities/risk_report_detail_entity.dart';
import '../domain/entities/risk_report_entity.dart';

class RiskAnalysisRepository {
  RiskAnalysisRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  int? _resolveTargetProfileId(String? profileId) {
    if (profileId == null || profileId.isEmpty || profileId == 'self') {
      return null;
    }
    return int.tryParse(profileId);
  }

  RiskLevel _parseRiskLevel(String? rawLevel) {
    switch (rawLevel?.trim().toLowerCase()) {
      case 'low':
        return RiskLevel.low;
      case 'moderate':
      case 'medium':
      case 'high':
        return RiskLevel.medium;
      case 'critical':
        return RiskLevel.critical;
      default:
        return RiskLevel.medium;
    }
  }

  int _parseScore(dynamic value) {
    if (value is num) {
      return value.round();
    }
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  int? _parseNullableScore(dynamic value) {
    if (value is num) {
      return value.round();
    }
    return null;
  }

  List<int> _parseTrend(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value.map((item) => _parseScore(item)).toList();
  }

  SnapshotMetrics _parseSnapshot(Map<String, dynamic> json) {
    return SnapshotMetrics(
      heartRate: _parseScore(json['heart_rate']),
      spO2: _parseScore(json['spo2']),
      sysBp: _parseScore(json['sys_bp']),
      diaBp: _parseScore(json['dia_bp']),
      bodyTemp: json['body_temp'] is num
          ? (json['body_temp'] as num).toDouble()
          : 0,
      hrv: _parseScore(json['hrv']),
      mapVal: _parseScore(json['map_val']),
    );
  }

  FactorBreakdown _parseBreakdownItem(Map<String, dynamic> json) {
    return FactorBreakdown(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      contributionScore: _parseDouble(json['contribution_score']),
      impactLevel: json['impact_level'] as String? ?? 'low',
      value: json['value'] as String? ?? '--',
      unit: json['unit'] as String? ?? '',
      routeTarget: json['route_target'] as String? ?? '',
      direction: json['direction'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  TopFactor _parseTopFactor(Map<String, dynamic> json) {
    return TopFactor(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      impact: _parseDouble(json['impact']),
      direction: json['direction'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      featureValue: json['feature_value'] as String? ?? '',
    );
  }

  AiExplanation _parseAiExplanation(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return AiExplanation.empty;
    final actionsRaw = json['recommended_actions'] as List? ?? const [];
    return AiExplanation(
      shortText: json['short_text'] as String? ?? '',
      clinicalNote: json['clinical_note'] as String? ?? '',
      recommendedActions: actionsRaw
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  Future<RiskReportEntity> fetchLatestReport(String? profileId) async {
    final targetProfileId = _resolveTargetProfileId(profileId);
    final result = await _apiClient.get(
      '/analysis/risk-reports',
      requiresAuth: true,
      queryParams: {'limit': 1},
      targetProfileId: targetProfileId,
    );
    if (result is! List) {
      throw const FormatException(
        'Unexpected /analysis/risk-reports response shape.',
      );
    }
    final data = result;
    if (data.isEmpty) {
      throw Exception('Chưa có dữ liệu đánh giá');
    }

    final json = Map<String, dynamic>.from(data.first as Map);
    final topFactors = (json['top_factors'] as List? ?? const [])
        .map((item) => _parseTopFactor(Map<String, dynamic>.from(item as Map)))
        .toList();

    return RiskReportEntity(
      reportId: json['id'] as int? ?? 0,
      profileId: profileId ?? 'self',
      // Phase 1: prefer canonical `score`; fall back to deprecated `risk_score`
      // for older backends. The deprecated alias will be removed in Phase 6.
      score: _parseScore(json['score'] ?? json['risk_score']),
      level: _parseRiskLevel(json['risk_level'] as String?),
      displayStatus: json['display_status'] as String? ?? 'Không xác định',
      summary: json['summary'] as String? ?? '',
      analyzedAt: DateTime.parse(json['timestamp'] as String),
      previousScore: _parseNullableScore(json['previous_score']),
      trend7d: _parseTrend(json['trend_7d']),
      topFactors: topFactors,
      recommendationPreview: List<String>.from(
        json['recommendation_preview'] as List? ?? const [],
      ),
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0,
      isStale: json['is_stale'] as bool? ?? true,
    );
  }

  Future<RiskReportDetailEntity> fetchReportDetail(
    int reportId,
    String? profileId,
  ) async {
    final targetProfileId = _resolveTargetProfileId(profileId);
    final result = await _apiClient.get(
      '/analysis/risk-reports/$reportId',
      requiresAuth: true,
      targetProfileId: targetProfileId,
    );
    final json = Map<String, dynamic>.from(result as Map);
    final topFactors = (json['top_factors'] as List? ?? const [])
        .map((item) => _parseTopFactor(Map<String, dynamic>.from(item as Map)))
        .toList();
    final aiExplanationRaw = json['ai_explanation'];
    final aiExplanation = _parseAiExplanation(
      aiExplanationRaw is Map
          ? Map<String, dynamic>.from(aiExplanationRaw)
          : null,
    );

    return RiskReportDetailEntity(
      reportId: json['id'] as int? ?? reportId,
      profileId: profileId ?? 'self',
      // Phase 1: prefer canonical `score`; fall back to deprecated `risk_score`.
      score: _parseScore(json['score'] ?? json['risk_score']),
      healthScore: _parseDouble(json['health_score']),
      level: _parseRiskLevel(json['risk_level'] as String?),
      displayStatus: json['display_status'] as String? ?? 'Không xác định',
      summary: json['summary'] as String? ?? '',
      analyzedAt: DateTime.parse(json['timestamp'] as String),
      previousScore: _parseNullableScore(json['previous_score']),
      trend7d: _parseTrend(json['trend_7d']),
      breakdown: (json['breakdown'] as List? ?? const [])
          .map(
            (item) =>
                _parseBreakdownItem(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      // Phase 1: prefer canonical `explanation`; fall back to deprecated
      // `xai_explanation`. The deprecated alias will be removed in Phase 6.
      xaiExplanation:
          json['explanation'] as String? ??
          json['xai_explanation'] as String? ??
          '',
      recommendations: List<String>.from(
        json['recommendations'] as List? ?? const [],
      ),
      recommendationPreview: List<String>.from(
        json['recommendation_preview'] as List? ?? const [],
      ),
      topFactors: topFactors,
      snapshot: _parseSnapshot(
        Map<String, dynamic>.from(json['snapshot'] as Map? ?? const {}),
      ),
      confidence: _parseDouble(json['confidence']),
      isStale: json['is_stale'] as bool? ?? true,
      aiExplanation: aiExplanation,
    );
  }

  Future<RiskHistoryEntity> fetchHistory({
    required String? profileId,
    String range = '7d',
    int page = 1,
    int limit = 20,
  }) async {
    final targetProfileId = _resolveTargetProfileId(profileId);
    final result = await _apiClient.get(
      '/analysis/risk-history',
      requiresAuth: true,
      queryParams: {'range': range, 'page': page, 'limit': limit},
      targetProfileId: targetProfileId,
    );
    final json = Map<String, dynamic>.from(result as Map);
    final summaryJson = Map<String, dynamic>.from(
      json['summary'] as Map? ?? const {},
    );

    return RiskHistoryEntity(
      range: json['range'] as String? ?? range,
      summary: RiskHistorySummary(
        averageScore: _parseDouble(summaryJson['average_score']),
        highestScore: _parseDouble(summaryJson['highest_score']),
        lowestScore: _parseDouble(summaryJson['lowest_score']),
        deltaVsPreviousPeriod: _parseDouble(
          summaryJson['delta_vs_previous_period'],
        ),
        trendPoints: _parseTrend(summaryJson['trend_points']),
      ),
      items: (json['items'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (item) => RiskHistoryItemEntity(
              reportId: item['report_id'] as int? ?? 0,
              // Phase 1: prefer canonical `score`; fall back to deprecated
              // `risk_score` so older backends still parse.
              score: _parseScore(item['score'] ?? item['risk_score']),
              healthScore: _parseDouble(item['health_score']),
              level: _parseRiskLevel(item['risk_level'] as String?),
              displayStatus:
                  item['display_status'] as String? ?? 'Không xác định',
              analyzedAt: DateTime.parse(item['analyzed_at'] as String),
              reasonPreview: item['reason_preview'] as String? ?? '',
              isStale: item['is_stale'] as bool? ?? true,
            ),
          )
          .toList(),
      page: json['page'] as int? ?? page,
      limit: json['limit'] as int? ?? limit,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
