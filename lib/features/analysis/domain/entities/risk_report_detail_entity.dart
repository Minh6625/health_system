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

/// Phase 8 slice 4b — clinician-only SHAP waterfall payload.
///
/// Mirrors ``backend/app/schemas/monitoring.py::RiskReportClinicianResponse.shap_details``
/// (which itself wraps the model-api ``ShapDetails``). Patient
/// responses don't carry this field; the entity stores ``null`` for
/// patient-mode detail loads.
class ShapWaterfall {
  /// True when the upstream model produced a usable SHAP payload.
  final bool available;

  /// SHAP base value (E[f(X)] — the model's mean prediction across
  /// training data). Bars on the waterfall are anchored to this baseline.
  final double baseValue;

  /// Final prediction value (base_value + sum of all contributions).
  /// Null when the backend did not include it (older model versions).
  final double? predictionValue;

  /// Per-feature contributions. Length is bounded by the model-api
  /// `top_n` config (typically <=20).
  final List<ShapContribution> values;

  const ShapWaterfall({
    required this.available,
    required this.baseValue,
    this.predictionValue,
    required this.values,
  });

  bool get hasValues => available && values.isNotEmpty;

  /// Sum of all contributions on top of the base value.
  double get totalContribution =>
      values.fold<double>(0, (acc, v) => acc + v.shapValue);

  /// Final prediction: prefer the backend-supplied value, fall back to
  /// base_value + totalContribution.
  double get finalPrediction =>
      predictionValue ?? (baseValue + totalContribution);

  static const ShapWaterfall empty = ShapWaterfall(
    available: false,
    baseValue: 0,
    values: [],
  );
}

/// One feature's SHAP contribution.
class ShapContribution {
  /// Backend feature name (snake_case, model-api domain).
  final String feature;

  /// Raw SHAP value. Positive = pushes prediction up (higher risk),
  /// negative = protective.
  final double shapValue;

  /// Pre-computed magnitude (abs(shap_value)) for sorting.
  final double impact;

  /// Actual measured value for this feature at prediction time
  /// (e.g. spo2=92.5). May be null for derived/categorical features.
  final double? featureValue;

  const ShapContribution({
    required this.feature,
    required this.shapValue,
    required this.impact,
    this.featureValue,
  });

  bool get isProtective => shapValue < 0;
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

  /// Phase 8 slice 4b — populated only when the request was made with
  /// ``audience=clinician`` AND the user has the role gate. ``null``
  /// for the default patient flow so existing callers ignore it.
  final ShapWaterfall? shapDetails;

  /// Phase 8 slice 4b — model-api request id surfaced for log
  /// correlation. ``null`` for patient responses + for fallback
  /// inference (rule_based / ONNX) where there's no upstream
  /// request to correlate with.
  final String? modelRequestId;

  // ADR-018 data quality contract (Phase 7 S11). Same semantics as
  // [RiskReportEntity] — present here too so the detail screen can
  // render the banner without needing the list entity.
  final bool isSyntheticDefault;
  final List<String>? defaultsApplied;
  final double? effectiveConfidence;
  final String? dataQualityWarning;

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
    this.shapDetails,
    this.modelRequestId,
    this.isSyntheticDefault = false,
    this.defaultsApplied,
    this.effectiveConfidence,
    this.dataQualityWarning,
  });

  /// True when the response carried clinician-only SHAP details that
  /// the screen can render. Used by ``RiskReportDetailScreen`` to
  /// decide whether to show the "Xem chi tiết SHAP" link.
  bool get hasClinicianShapDetails =>
      shapDetails != null && shapDetails!.hasValues;
}
