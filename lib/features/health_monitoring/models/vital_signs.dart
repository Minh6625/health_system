import 'package:healthguard/core/services/threshold_service.dart';

enum VitalStatus { normal, warning, critical, unknown }

/// P1-5 (2026-05-18): the classify* helpers now accept an optional
/// [ThresholdConfig] argument. When omitted they read from
/// `ThresholdService.instance.config`, which initialises to the
/// rules_config v2.0.0 defaults and is updated when
/// `GET /api/v1/mobile/settings/thresholds` returns. Callers therefore
/// keep the same signature — colour zones move with the BE without a
/// rebuild.

VitalStatus classifyHeartRateStatus(double? heartRate, {ThresholdConfig? config}) {
  if (heartRate == null) {
    return VitalStatus.unknown;
  }
  final t = (config ?? ThresholdService.instance.config).heartRate;
  if (heartRate <= t.urgentLow || heartRate >= t.urgentHigh) {
    return VitalStatus.critical;
  }
  if (heartRate <= t.sendLow || heartRate >= t.sendHigh) {
    return VitalStatus.warning;
  }
  if (heartRate >= t.watchHigh) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifySpo2Status(double? spo2, {ThresholdConfig? config}) {
  if (spo2 == null) {
    return VitalStatus.unknown;
  }
  final t = (config ?? ThresholdService.instance.config).spo2;
  if (spo2 < t.urgentLow) {
    return VitalStatus.critical;
  }
  if (spo2 <= t.sendLow) {
    return VitalStatus.warning;
  }
  if (spo2 <= t.watchLow) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyTemperatureStatus(
  double? temperature, {
  ThresholdConfig? config,
}) {
  if (temperature == null) {
    return VitalStatus.unknown;
  }
  final t = (config ?? ThresholdService.instance.config).bodyTemp;
  if (temperature <= t.urgentLow || temperature >= t.urgentHigh) {
    return VitalStatus.critical;
  }
  if (temperature <= t.sendLow || temperature >= t.sendHigh) {
    return VitalStatus.warning;
  }
  if (temperature >= t.watchHigh) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyBloodPressureSystolicStatus(
  double? systolic, {
  ThresholdConfig? config,
}) {
  if (systolic == null) {
    return VitalStatus.unknown;
  }
  final t = (config ?? ThresholdService.instance.config).sysBp;
  if (systolic <= t.urgentLow || systolic >= t.urgentHigh) {
    return VitalStatus.critical;
  }
  if (systolic <= t.sendLow || systolic >= t.sendHigh) {
    return VitalStatus.warning;
  }
  if (systolic >= t.watchHigh) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyBloodPressureDiastolicStatus(
  double? diastolic, {
  ThresholdConfig? config,
}) {
  if (diastolic == null) {
    return VitalStatus.unknown;
  }
  final t = (config ?? ThresholdService.instance.config).diaBp;
  if (diastolic >= t.urgentHigh) {
    return VitalStatus.critical;
  }
  if (diastolic >= t.sendHigh) {
    return VitalStatus.warning;
  }
  if (diastolic >= t.watchHigh) {
    return VitalStatus.warning;
  }
  return VitalStatus.normal;
}

VitalStatus classifyBloodPressureStatus({
  required double? systolic,
  required double? diastolic,
  ThresholdConfig? config,
}) {
  final systolicStatus = classifyBloodPressureSystolicStatus(systolic, config: config);
  final diastolicStatus = classifyBloodPressureDiastolicStatus(diastolic, config: config);
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

VitalStatus classifyRespiratoryRateStatus(
  double? respiratoryRate, {
  ThresholdConfig? config,
}) {
  if (respiratoryRate == null) {
    return VitalStatus.unknown;
  }
  final t = (config ?? ThresholdService.instance.config).respRate;
  if (respiratoryRate <= t.urgentLow || respiratoryRate >= t.urgentHigh) {
    return VitalStatus.critical;
  }
  if (respiratoryRate >= t.sendHigh) {
    return VitalStatus.warning;
  }
  if (respiratoryRate >= t.watchHigh) {
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
