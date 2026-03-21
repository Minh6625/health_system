import '../../domain/entities/risk_report_entity.dart';

class RiskHistoryItemEntity {
  final String reportId;
  final int score;
  final RiskLevel level;
  final DateTime analyzedAt;
  final String reasonPreview;

  RiskHistoryItemEntity({
    required this.reportId,
    required this.score,
    required this.level,
    required this.analyzedAt,
    required this.reasonPreview,
  });
}

class RiskHistorySummary {
  final int averageScore;
  final int highestScore;
  final int lowestScore;
  final int deltaVsPreviousPeriod;
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
