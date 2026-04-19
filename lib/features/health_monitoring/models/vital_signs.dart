enum VitalStatus { normal, warning, critical, unknown }

VitalStatus classifyHeartRateStatus(double? heartRate) {
  if (heartRate == null) {
    return VitalStatus.unknown;
  }
  if (heartRate < 50 || heartRate > 120) {
    return VitalStatus.critical;
  }
  if ((heartRate >= 50 && heartRate < 60) ||
      (heartRate > 100 && heartRate <= 120)) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifySpo2Status(double? spo2) {
  if (spo2 == null) {
    return VitalStatus.unknown;
  }
  if (spo2 < 92) {
    return VitalStatus.critical;
  }
  if (spo2 < 95) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyTemperatureStatus(double? temperature) {
  if (temperature == null) {
    return VitalStatus.unknown;
  }
  if (temperature >= 37.8 || temperature < 35.5) {
    return VitalStatus.critical;
  }
  if ((temperature >= 37.3 && temperature < 37.8) ||
      (temperature >= 35.5 && temperature < 36.1)) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyBloodPressureSystolicStatus(double? systolic) {
  if (systolic == null) {
    return VitalStatus.unknown;
  }
  if (systolic >= 140 || systolic < 70) {
    return VitalStatus.critical;
  }
  if ((systolic >= 121 && systolic < 140) ||
      (systolic >= 70 && systolic < 90)) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyBloodPressureDiastolicStatus(double? diastolic) {
  if (diastolic == null) {
    return VitalStatus.unknown;
  }
  if (diastolic >= 90 || diastolic < 50) {
    return VitalStatus.critical;
  }
  if ((diastolic >= 81 && diastolic < 90) ||
      (diastolic >= 50 && diastolic < 60)) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyBloodPressureStatus({
  required double? systolic,
  required double? diastolic,
}) {
  final systolicStatus = classifyBloodPressureSystolicStatus(systolic);
  final diastolicStatus = classifyBloodPressureDiastolicStatus(diastolic);
  if (systolicStatus == VitalStatus.critical ||
      diastolicStatus == VitalStatus.critical) {
    return VitalStatus.critical;
  }
  if (systolicStatus == VitalStatus.warning ||
      diastolicStatus == VitalStatus.warning) {
    return VitalStatus.warning;
  }
  if (systolicStatus == VitalStatus.unknown &&
      diastolicStatus == VitalStatus.unknown) {
    return VitalStatus.unknown;
  }
  return VitalStatus.normal;
}

VitalStatus classifyRespiratoryRateStatus(double? respiratoryRate) {
  if (respiratoryRate == null) {
    return VitalStatus.unknown;
  }
  if (respiratoryRate < 12 || respiratoryRate > 25) {
    return VitalStatus.critical;
  }
  if ((respiratoryRate >= 12 && respiratoryRate < 14) ||
      (respiratoryRate > 20 && respiratoryRate <= 25)) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

class VitalSigns {
  final double? heartRate;
  final double? spo2;
  final double? temperature;
  final double? respiratoryRate;
  final double? bloodPressureSys;
  final double? bloodPressureDia;
  final DateTime timestamp;
  final bool isStale;

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

  static DateTime _parseTimestamp(dynamic timestampValue) {
    if (timestampValue == null) {
      return DateTime.now();
    }
    var timestampString = timestampValue.toString();
    if (!timestampString.endsWith('Z') &&
        !timestampString.contains('T') &&
        timestampString.contains('-') &&
        timestampString.split('-').length == 3) {
      timestampString = '${timestampString.replaceAll(' ', 'T')}Z';
    }
    return DateTime.parse(timestampString).toLocal();
  }

  factory VitalSigns.fromJson(Map<String, dynamic> json) {
    return VitalSigns(
      heartRate: (json['heart_rate'] as num?)?.toDouble(),
      spo2: (json['spo2'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      respiratoryRate: (json['respiratory_rate'] as num?)?.toDouble(),
      bloodPressureSys: (json['blood_pressure_sys'] as num?)?.toDouble(),
      bloodPressureDia: (json['blood_pressure_dia'] as num?)?.toDouble(),
      timestamp: _parseTimestamp(json['timestamp']),
      isStale: json['is_stale'] as bool? ?? false,
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

  VitalStatus getHeartRateStatus() => classifyHeartRateStatus(heartRate);

  VitalStatus getSpo2Status() => classifySpo2Status(spo2);

  VitalStatus getTemperatureStatus() => classifyTemperatureStatus(temperature);

  VitalStatus getBloodPressureSysStatus() =>
      classifyBloodPressureSystolicStatus(bloodPressureSys);

  VitalStatus getBloodPressureDiaStatus() =>
      classifyBloodPressureDiastolicStatus(bloodPressureDia);

  VitalStatus getRespiratoryRateStatus() =>
      classifyRespiratoryRateStatus(respiratoryRate);
}
