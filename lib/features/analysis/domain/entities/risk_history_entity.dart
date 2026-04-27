import '../../domain/entities/risk_report_entity.dart';

class RiskHistoryItemEntity {
  final int reportId;
  final int score;
  final double healthScore;
  final RiskLevel level;
  final String displayStatus;
  final DateTime analyzedAt;
  final String reasonPreview;
  final bool isStale;

  RiskHistoryItemEntity({
    required this.reportId,
    required this.score,
    required this.healthScore,
    required this.level,
    required this.displayStatus,
    required this.analyzedAt,
    required this.reasonPreview,
    required this.isStale,
  });
}

class RiskHistorySummary {
  /// Risk-domain stats from the backend. Kept as-is for storage parity; UI
  /// should prefer the `health*` getters below which invert the semantic.
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final double deltaVsPreviousPeriod;
  final List<int> trendPoints;

  RiskHistorySummary({
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.deltaVsPreviousPeriod,
    required this.trendPoints,
  });

  /// Average health score (0–100, higher is better) for the period.
  double get healthAverage => (100 - averageScore).clamp(0.0, 100.0);

  /// Best (highest) health score in the period — the inverse of the worst
  /// (highest) risk score.
  double get healthHighest => (100 - lowestScore).clamp(0.0, 100.0);

  /// Worst (lowest) health score in the period — the inverse of the best
  /// (lowest) risk score.
  double get healthLowest => (100 - highestScore).clamp(0.0, 100.0);

  /// Period-over-period delta in the health domain. Positive means health
  /// improved compared to the previous period.
  double get healthDeltaVsPreviousPeriod => -deltaVsPreviousPeriod;

  /// Trend points re-expressed in the health domain so charts rendered
  /// upward represent improvement.
  List<int> get healthTrendPoints =>
      trendPoints.map((point) => (100 - point).clamp(0, 100)).toList();
}

class RiskHistoryEntity {
  final String range;
  final RiskHistorySummary summary;
  final List<RiskHistoryItemEntity> items;
  final int page;
  final int limit;
  final bool hasMore;

  RiskHistoryEntity({
    required this.range,
    required this.summary,
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}
