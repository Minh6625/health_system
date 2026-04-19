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
      contributionScore: _parseScore(json['contribution_score']),
      impactLevel: json['impact_level'] as String? ?? 'low',
      value: json['value'] as String? ?? '--',
      unit: json['unit'] as String? ?? '',
      routeTarget: json['route_target'] as String? ?? '',
    );
  }

  TopFactor _parseTopFactor(Map<String, dynamic> json) {
    return TopFactor(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
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
    final data = result is List
        ? result
        : (result['data'] as List? ?? const []);
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
      score: _parseScore(json['risk_score'] ?? json['score']),
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

    return RiskReportDetailEntity(
      reportId: json['id'] as int? ?? reportId,
      profileId: profileId ?? 'self',
      score: _parseScore(json['risk_score'] ?? json['score']),
      level: _parseRiskLevel(json['risk_level'] as String?),
      summary: json['summary'] as String? ?? '',
      analyzedAt: DateTime.parse(json['timestamp'] as String),
      breakdown: (json['breakdown'] as List? ?? const [])
          .map(
            (item) =>
                _parseBreakdownItem(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      xaiExplanation:
          json['xai_explanation'] as String? ??
          json['explanation'] as String? ??
          '',
      recommendations: List<String>.from(
        json['recommendations'] as List? ?? const [],
      ),
      snapshot: _parseSnapshot(
        Map<String, dynamic>.from(json['snapshot'] as Map? ?? const {}),
      ),
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
        averageScore: _parseScore(summaryJson['average_score']),
        highestScore: _parseScore(summaryJson['highest_score']),
        lowestScore: _parseScore(summaryJson['lowest_score']),
        deltaVsPreviousPeriod: _parseScore(
          summaryJson['delta_vs_previous_period'],
        ),
        trendPoints: _parseTrend(summaryJson['trend_points']),
      ),
      items: (json['items'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(
            (item) => RiskHistoryItemEntity(
              reportId: item['report_id'] as int? ?? 0,
              score: _parseScore(item['risk_score'] ?? item['score']),
              level: _parseRiskLevel(item['risk_level'] as String?),
              analyzedAt: DateTime.parse(item['analyzed_at'] as String),
              reasonPreview: item['reason_preview'] as String? ?? '',
            ),
          )
          .toList(),
      page: json['page'] as int? ?? page,
      limit: json['limit'] as int? ?? limit,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
