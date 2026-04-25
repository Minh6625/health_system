import 'risk_report_entity.dart';

class FactorBreakdown {
  final String key;
  final String label;
  final double contributionScore;
  final String impactLevel;
  final String value;
  final String unit;
  final String routeTarget;
  final String direction;
  final String reason;

  FactorBreakdown({
    required this.key,
    required this.label,
    required this.contributionScore,
    required this.impactLevel,
    required this.value,
    required this.unit,
    required this.routeTarget,
    this.direction = '',
    this.reason = '',
  });

  bool get isRiskUp => direction == 'risk_up';
  bool get isRiskDown => direction == 'risk_down';
  bool get hasShapContext => direction.isNotEmpty;
}

class AiExplanation {
  final String shortText;
  final String clinicalNote;
  final List<String> recommendedActions;

  const AiExplanation({
    this.shortText = '',
    this.clinicalNote = '',
    this.recommendedActions = const [],
  });

  bool get isEmpty =>
      shortText.isEmpty && clinicalNote.isEmpty && recommendedActions.isEmpty;

  bool get isNotEmpty => !isEmpty;

  static const AiExplanation empty = AiExplanation();
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
  final double healthScore;
  final RiskLevel level;
  final String displayStatus;
  final String summary;
  final DateTime analyzedAt;
  final int? previousScore;
  final List<int> trend7d;
  final List<FactorBreakdown> breakdown;
  final String xaiExplanation;
  final List<String> recommendations;
  final List<String> recommendationPreview;
  final List<TopFactor> topFactors;
  final SnapshotMetrics snapshot;
  final double confidence;
  final bool isStale;
  final AiExplanation aiExplanation;

  RiskReportDetailEntity({
    required this.reportId,
    required this.profileId,
    required this.score,
    required this.healthScore,
    required this.level,
    required this.displayStatus,
    required this.summary,
    required this.analyzedAt,
    required this.previousScore,
    required this.trend7d,
    required this.breakdown,
    required this.xaiExplanation,
    required this.recommendations,
    required this.recommendationPreview,
    required this.topFactors,
    required this.snapshot,
    required this.confidence,
    required this.isStale,
    this.aiExplanation = AiExplanation.empty,
  });
}
