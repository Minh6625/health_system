class FamilyProfileSnapshot {
  final String id;
  final String name;
  final String relation;
  final int heartRate;
  final int spo2;
  // Huyết áp (mmHg)
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  // Nhiệt độ cơ thể (°C)
  final double? bodyTemperature;
  final String riskLevel; // 'low', 'medium', 'high'
  final bool isSosActive;

  /// sosId khi isSosActive = true — dùng để navigate đến EmergencySOSDetailScreen
  final String? sosId;
  final bool hasViewVitalsPermission;
  final bool hasVitalsData;
  final String? vitalsDataMessage;

  /// Đánh dấu ưu tiên (Pinned) — dùng cho filter "Ưu tiên", không hardcode role
  final bool isPinned;
  final DateTime lastUpdated;
  final String specialNote; // e.g. "Huyết áp cần theo dõi"

  // Sleep data
  final int sleepDurationMinutes; // e.g. 390 = 6h30
  final String sleepQuality; // 'Tốt', 'Trung bình', 'Kém'

  // Health score 7 ngày
  final int healthScore7Days; // 0–100
  final String healthScoreLevel; // 'Thấp', 'Trung bình', 'Cao'

  FamilyProfileSnapshot({
    required this.id,
    required this.name,
    required this.relation,
    this.heartRate = 0,
    this.spo2 = 0,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.bodyTemperature,
    this.riskLevel = 'low',
    this.isSosActive = false,
    this.sosId,
    this.hasViewVitalsPermission = true,
    this.hasVitalsData = true,
    this.vitalsDataMessage,
    this.isPinned = false,
    required this.lastUpdated,
    this.specialNote = '',
    this.sleepDurationMinutes = 420,
    this.sleepQuality = 'Tốt',
    this.healthScore7Days = 70,
    this.healthScoreLevel = 'Trung bình',
  });

  factory FamilyProfileSnapshot.fromJson(Map<String, dynamic> json) {
    return FamilyProfileSnapshot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'N/A',
      relation: json['relation'] as String? ?? '',
      heartRate: json['heart_rate'] as int? ?? 0,
      spo2: json['spo2'] as int? ?? 0,
      bloodPressureSystolic: json['blood_pressure_systolic'] as int?,
      bloodPressureDiastolic: json['blood_pressure_diastolic'] as int?,
      bodyTemperature: (json['body_temperature'] as num?)?.toDouble(),
      riskLevel: json['risk_level'] as String? ?? 'low',
      isSosActive: json['is_sos_active'] as bool? ?? false,
      sosId: json['sos_id'] as String?,
      hasViewVitalsPermission:
          json['has_view_vitals_permission'] as bool? ?? true,
      hasVitalsData: json['has_vitals_data'] as bool? ?? true,
      vitalsDataMessage: json['vitals_data_message'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
      specialNote: json['special_note'] as String? ?? '',
      sleepDurationMinutes: json['sleep_duration_minutes'] as int? ?? 0,
      sleepQuality: json['sleep_quality'] as String? ?? 'Trung bình',
      healthScore7Days: json['health_score_7_days'] as int? ?? 0,
      healthScoreLevel: json['health_score_level'] as String? ?? 'Trung bình',
    );
  }

  /// Chuỗi huyết áp dạng "120/80"
  String? get bloodPressureDisplay {
    if (bloodPressureSystolic == null || bloodPressureDiastolic == null) {
      return null;
    }
    return '$bloodPressureSystolic/$bloodPressureDiastolic';
  }

  /// Chuỗi nhiệt độ dạng "36.8°"
  String? get bodyTemperatureDisplay {
    if (bodyTemperature == null) return null;
    return '${bodyTemperature!.toStringAsFixed(1)}°';
  }
}
