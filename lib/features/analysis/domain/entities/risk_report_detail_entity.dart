import 'risk_report_entity.dart';

class FactorBreakdown {
  final String key;
  final String label;
  final int contributionScore; // can be negative or positive
  final String impactLevel; // high, medium, low
  final String value;
  final String unit;
  final String routeTarget;

  FactorBreakdown({
    required this.key,
    required this.label,
    required this.contributionScore,
    required this.impactLevel,
    required this.value,
    required this.unit,
    required this.routeTarget,
  });
}

class SnapshotMetrics {
  final int heartRate;
  final int spO2;
  final int sysBp;
  final int diaBp;
  final double bodyTemp;
  final int hrv;
  final int mapVal;

  SnapshotMetrics({
    required this.heartRate,
    required this.spO2,
    required this.sysBp,
    required this.diaBp,
    required this.bodyTemp,
    required this.hrv,
    required this.mapVal,
  });
}

class RiskReportDetailEntity {
  final int reportId;
  final String profileId;
  final int score;
  final RiskLevel level;
  final String summary;
  final DateTime analyzedAt;
  final List<FactorBreakdown> breakdown;
  final String xaiExplanation;
  final List<String> recommendations;
  final SnapshotMetrics snapshot;

  RiskReportDetailEntity({
    required this.reportId,
    required this.profileId,
    required this.score,
    required this.level,
    required this.summary,
    required this.analyzedAt,
    required this.breakdown,
    required this.xaiExplanation,
    required this.recommendations,
    required this.snapshot,
  });
}
