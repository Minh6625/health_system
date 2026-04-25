/// Aggregated health report payload returned by `/metrics/health-report`.
///
/// Covers 24h vital averages, latest AI risk score, and a derived "health
/// score" used by the report screen as a hero card.
class HealthReport {
  const HealthReport({
    required this.vitals24hAvg,
    required this.lastUpdated,
    required this.isStale,
    this.latestRiskScore,
    this.riskLevel,
    this.riskType,
    this.healthScore,
    this.healthLevel,
    this.healthSummary,
    this.confidence,
  });

  /// Map keyed by canonical vital name (`heart_rate`, `spo2`,
  /// `blood_pressure_sys`, `blood_pressure_dia`, `temperature`,
  /// `respiratory_rate`). Values are 24-hour averages or `null` when no
  /// data is available for that metric.
  final Map<String, num?> vitals24hAvg;

  final double? latestRiskScore;
  final String? riskLevel;
  final String? riskType;

  final DateTime? lastUpdated;

  final double? healthScore;
  final String? healthLevel;
  final String? healthSummary;
  final double? confidence;

  /// `true` when the backend reports stale data (no fresh vitals in 24h).
  final bool isStale;

  factory HealthReport.fromJson(Map<String, dynamic> json) {
    final raw = json['vitals_24h_avg'];
    final vitals = <String, num?>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        vitals[key.toString()] = value is num ? value : null;
      });
    }

    DateTime? parseDate(Object? value) {
      if (value == null) return null;
      if (value is DateTime) return value.toLocal();
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return HealthReport(
      vitals24hAvg: vitals,
      latestRiskScore: (json['latest_risk_score'] as num?)?.toDouble(),
      riskLevel: json['risk_level'] as String?,
      riskType: json['risk_type'] as String?,
      lastUpdated: parseDate(json['last_updated']),
      healthScore: (json['health_score'] as num?)?.toDouble(),
      healthLevel: json['health_level'] as String?,
      healthSummary: json['health_summary'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isStale: json['is_stale'] == true,
    );
  }
}
