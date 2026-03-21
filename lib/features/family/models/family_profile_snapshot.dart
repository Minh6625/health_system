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
    this.isPinned = false,
    required this.lastUpdated,
    this.specialNote = '',
    this.sleepDurationMinutes = 420,
    this.sleepQuality = 'Tốt',
    this.healthScore7Days = 70,
    this.healthScoreLevel = 'Trung bình',
  });

  /// Chuỗi huyết áp dạng "120/80"
  String? get bloodPressureDisplay {
    if (bloodPressureSystolic == null || bloodPressureDiastolic == null) return null;
    return '$bloodPressureSystolic/$bloodPressureDiastolic';
  }

  /// Chuỗi nhiệt độ dạng "36.8°"
  String? get bodyTemperatureDisplay {
    if (bodyTemperature == null) return null;
    return '${bodyTemperature!.toStringAsFixed(1)}°';
  }
}
