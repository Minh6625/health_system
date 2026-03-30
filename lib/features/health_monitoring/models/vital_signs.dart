class VitalSigns {
  final double? heartRate; // BPM
  final double? spo2; // %
  final double? temperature; // °C
  final double? respiratoryRate; // breaths per minute
  final double? bloodPressureSys; // mmHg (tâm thu)
  final double? bloodPressureDia; // mmHg (tâm trương)
  final DateTime timestamp;
  final bool isStale; // Data older than the backend stale threshold

  VitalSigns({
    this.heartRate,
    this.spo2,
    this.temperature,
    this.respiratoryRate,
    this.bloodPressureSys,
    this.bloodPressureDia,
    required this.timestamp,
    this.isStale = false,
  });
  static DateTime _parseTimestamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    String tsStr = ts.toString();
    if (!tsStr.endsWith('Z') && !tsStr.contains('T') && tsStr.contains('-') && tsStr.split('-').length == 3) {
       // if it's just a raw format '2024-03-15 14:30:00', Dart parse treats as local, let's assume UTC from backend
       tsStr = '${tsStr.replaceAll(' ', 'T')}Z';
    }
    return DateTime.parse(tsStr).toLocal();
  }

  factory VitalSigns.fromJson(Map<String, dynamic> json) {
    return VitalSigns(
      heartRate: json['heart_rate']?.toDouble(),
      spo2: json['spo2']?.toDouble(),
      temperature: json['temperature']?.toDouble(),
      respiratoryRate: json['respiratory_rate']?.toDouble(),
      bloodPressureSys: json['blood_pressure_sys']?.toDouble(),
      bloodPressureDia: json['blood_pressure_dia']?.toDouble(),
      timestamp: _parseTimestamp(json['timestamp']),
      isStale: json['is_stale'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heart_rate': heartRate,
      'spo2': spo2,
      'temperature': temperature,
      'respiratory_rate': respiratoryRate,
      'blood_pressure_sys': bloodPressureSys,
      'blood_pressure_dia': bloodPressureDia,
      'timestamp': timestamp.toIso8601String(),
      'is_stale': isStale,
    };
  }

  // Color coding based on thresholds from UC006
  VitalStatus getHeartRateStatus() {
    if (heartRate == null) return VitalStatus.unknown;
    if (heartRate! < 50 || heartRate! > 120) return VitalStatus.critical;
    if ((heartRate! >= 50 && heartRate! < 60) ||
        (heartRate! > 100 && heartRate! <= 120)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus getSpo2Status() {
    if (spo2 == null) return VitalStatus.unknown;
    if (spo2! < 92) return VitalStatus.critical;
    if (spo2! >= 92 && spo2! < 95) return VitalStatus.warning;
    return VitalStatus.normal;
  }

  VitalStatus getTemperatureStatus() {
    if (temperature == null) return VitalStatus.unknown;
    if (temperature! >= 37.8 || temperature! < 35.5) return VitalStatus.critical;
    if ((temperature! >= 37.3 && temperature! < 37.8) ||
        (temperature! >= 35.5 && temperature! < 36.1)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus getBloodPressureSysStatus() {
    if (bloodPressureSys == null) return VitalStatus.unknown;
    if (bloodPressureSys! >= 140 || bloodPressureSys! < 70) {
      return VitalStatus.critical;
    }
    if ((bloodPressureSys! >= 121 && bloodPressureSys! < 140) ||
        (bloodPressureSys! >= 70 && bloodPressureSys! < 90)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus getBloodPressureDiaStatus() {
    if (bloodPressureDia == null) return VitalStatus.unknown;
    if (bloodPressureDia! >= 90 || bloodPressureDia! < 50) {
      return VitalStatus.critical;
    }
    if ((bloodPressureDia! >= 81 && bloodPressureDia! < 90) ||
        (bloodPressureDia! >= 50 && bloodPressureDia! < 60)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }

  VitalStatus getRespiratoryRateStatus() {
    if (respiratoryRate == null) return VitalStatus.unknown;
    if (respiratoryRate! < 12 || respiratoryRate! > 25) {
      return VitalStatus.critical;
    }
    if ((respiratoryRate! >= 12 && respiratoryRate! < 14) ||
        (respiratoryRate! > 20 && respiratoryRate! <= 25)) {
      return VitalStatus.warning;
    }
    return VitalStatus.normal;
  }
}

enum VitalStatus {
  normal, // Green
  warning, // Yellow/Orange
  critical, // Red
  unknown, // Grey
}
