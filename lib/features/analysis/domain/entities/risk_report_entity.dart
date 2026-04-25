enum RiskLevel { low, medium, critical }

class TopFactor {
  final String key;
  final String label;
  final double impact;
  final String direction;
  final String reason;
  final String featureValue;

  TopFactor({
    required this.key,
    required this.label,
    this.impact = 0.0,
    this.direction = '',
    this.reason = '',
    this.featureValue = '',
  });

  bool get isRiskUp => direction == 'risk_up';
  bool get isRiskDown => direction == 'risk_down';
  bool get hasShapContext => direction.isNotEmpty || impact > 0;
}

class RiskReportEntity {
  final int reportId;
  final String profileId;
  final int score;
  final RiskLevel level;
  final String displayStatus;
  final String summary;
  final DateTime analyzedAt;
  final int? previousScore;
  final List<int> trend7d;
  final List<TopFactor> topFactors;
  final List<String> recommendationPreview;
  final double confidence;
  final bool isStale;

  RiskReportEntity({
    required this.reportId,
    required this.profileId,
    required this.score,
    required this.level,
    required this.displayStatus,
    required this.summary,
    required this.analyzedAt,
    required this.previousScore,
    required this.trend7d,
    required this.topFactors,
    required this.recommendationPreview,
    required this.confidence,
    required this.isStale,
  });
}
