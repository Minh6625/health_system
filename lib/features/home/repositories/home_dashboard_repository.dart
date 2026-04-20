import 'package:healthguard/core/network/api_client.dart';

class VitalSignsResponse {
  final double? heartRate;
  final double? spo2;
  final double? temperature;
  final double? respiratoryRate;
  final double? bloodPressureSys;
  final double? bloodPressureDia;
  final DateTime timestamp;
  final bool isStale;

  VitalSignsResponse({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.respiratoryRate,
    required this.bloodPressureSys,
    required this.bloodPressureDia,
    required this.timestamp,
    required this.isStale,
  });

  factory VitalSignsResponse.fromJson(Map<String, dynamic> json) {
    return VitalSignsResponse(
      heartRate: (json['heart_rate'] as num?)?.toDouble(),
      spo2: (json['spo2'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      respiratoryRate: (json['respiratory_rate'] as num?)?.toDouble(),
      bloodPressureSys: (json['blood_pressure_sys'] as num?)?.toDouble(),
      bloodPressureDia: (json['blood_pressure_dia'] as num?)?.toDouble(),
      timestamp: DateTime.parse(
        json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isStale: json['is_stale'] as bool? ?? false,
    );
  }
}

class HealthReportResponse {
  final Map<String, dynamic> vitals24hAvg;
  final double? latestRiskScore;
  final double? healthScore;
  final String? healthLevel;
  final String? healthSummary;
  final String? riskLevel;
  final String? riskType;
  final DateTime? lastUpdated;
  final double? confidence;
  final bool isStale;

  HealthReportResponse({
    required this.vitals24hAvg,
    required this.latestRiskScore,
    required this.healthScore,
    required this.healthLevel,
    required this.healthSummary,
    required this.riskLevel,
    required this.riskType,
    required this.lastUpdated,
    required this.confidence,
    required this.isStale,
  });

  factory HealthReportResponse.fromJson(Map<String, dynamic> json) {
    return HealthReportResponse(
      vitals24hAvg: json['vitals_24h_avg'] as Map<String, dynamic>? ?? {},
      latestRiskScore: (json['latest_risk_score'] as num?)?.toDouble(),
      healthScore: (json['health_score'] as num?)?.toDouble(),
      healthLevel: json['health_level'] as String?,
      healthSummary: json['health_summary'] as String?,
      riskLevel: json['risk_level'] as String?,
      riskType: json['risk_type'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
      isStale: json['is_stale'] as bool? ?? true,
    );
  }
}

class RiskReportResponse {
  final int id;
  final String riskType;
  final double score;
  final String riskLevel;
  final DateTime timestamp;
  final List<String> keyFeatures;

  RiskReportResponse({
    required this.id,
    required this.riskType,
    required this.score,
    required this.riskLevel,
    required this.timestamp,
    required this.keyFeatures,
  });

  factory RiskReportResponse.fromJson(Map<String, dynamic> json) {
    return RiskReportResponse(
      id: json['id'] as int,
      riskType: json['risk_type'] as String,
      score: (json['score'] as num).toDouble(),
      riskLevel: json['risk_level'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      keyFeatures: List<String>.from(json['key_features'] as List? ?? []),
    );
  }
}

class HomeDashboardRepository {
  HomeDashboardRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  int? _resolveTargetProfileId(String? profileId) {
    if (profileId == null || profileId.isEmpty || profileId == 'self') {
      return null;
    }
    return int.tryParse(profileId);
  }

  Future<VitalSignsResponse> getLatestVitalSigns({String? profileId}) async {
    final result = await _apiClient.get(
      '/metrics/vital-signs/latest',
      requiresAuth: true,
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    return VitalSignsResponse.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<HealthReportResponse> getHealthReport({String? profileId}) async {
    final result = await _apiClient.get(
      '/metrics/health-report',
      requiresAuth: true,
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    return HealthReportResponse.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  Future<List<RiskReportResponse>> getRiskReports({
    int limit = 5,
    String? profileId,
  }) async {
    final result = await _apiClient.get(
      '/analysis/risk-reports?limit=$limit',
      requiresAuth: true,
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    if (result is! List) {
      throw const FormatException(
        'Unexpected /analysis/risk-reports response shape.',
      );
    }
    return result
        .map(
          (item) => RiskReportResponse.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getLatestSleepSession({
    String? profileId,
  }) async {
    final result = await _apiClient.get(
      '/metrics/sleep/latest',
      requiresAuth: true,
      targetProfileId: _resolveTargetProfileId(profileId),
    );
    if (result == null) {
      return null;
    }
    if (result is! Map) {
      throw const FormatException(
        'Unexpected /metrics/sleep/latest response shape.',
      );
    }
    return Map<String, dynamic>.from(result);
  }
}
