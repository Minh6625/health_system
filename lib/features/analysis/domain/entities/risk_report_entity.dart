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

  /// Raw risk score returned by the backend (`risk_score`). Higher = worse
  /// health. Kept as the storage representation; UI should prefer
  /// [healthScore] which inverts the semantic so larger values are better.
  final int score;
  final RiskLevel level;
  final String displayStatus;
  final String summary;
  final DateTime analyzedAt;

  /// Risk score from the previous report, if any. UI should derive deltas
  /// from [healthDelta] which flips the sign so positive = improvement.
  final int? previousScore;
  final List<int> trend7d;
  final List<TopFactor> topFactors;
  final List<String> recommendationPreview;
  final double confidence;
  final bool isStale;

  // ADR-018 data quality contract (Phase 7 S11). Populated when the BE
  // inference used population defaults for one or more soft vitals (HRV,
  // BP, weight, height). When true the UI renders the warning banner.
  final bool isSyntheticDefault;
  final List<String>? defaultsApplied;
  final double? effectiveConfidence;
  final String? dataQualityWarning;

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
    this.isSyntheticDefault = false,
    this.defaultsApplied,
    this.effectiveConfidence,
    this.dataQualityWarning,
  });

  /// User-facing health score (0–100, higher is better). Computed as the
  /// complement of the underlying risk score.
  int get healthScore => (100 - score).clamp(0, 100);

  /// Difference in health score versus the previous report. Positive means
  /// health improved; null when there was no prior comparison.
  int? get healthDelta {
    final prev = previousScore;
    if (prev == null) return null;
    return prev - score;
  }

  /// Trend points expressed in the health domain (higher = better) so charts
  /// rendered upward indicate improvement.
  List<int> get healthTrend7d =>
      trend7d.map((point) => (100 - point).clamp(0, 100)).toList();
}
