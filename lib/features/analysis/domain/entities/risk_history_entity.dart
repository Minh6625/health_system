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
