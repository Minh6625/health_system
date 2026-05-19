/// Numeric thresholds used by [VitalSafeRangeBar] to draw the 5-zone gauge.
///
/// Zones (left → right):
/// 1. critical-low     [axisMin .. criticalLow)
/// 2. warning-low      [criticalLow .. normalLow)
/// 3. normal           [normalLow .. normalHigh]
/// 4. warning-high     (normalHigh .. criticalHigh]
/// 5. critical-high    (criticalHigh .. axisMax]
///
/// All thresholds derive from `ThresholdService.instance.config` (P1-5),
/// which is fed by the BE `/settings/thresholds` endpoint and falls back
/// to the rules_config v2.0.0 snapshot when offline. The classifiers in
/// `vital_signs.dart` read from the same source so the gauge always
/// agrees with the colored status pill.
import 'package:healthguard/core/services/threshold_service.dart';

class VitalSafeRange {
  const VitalSafeRange({
    required this.axisMin,
    required this.criticalLow,
    required this.normalLow,
    required this.normalHigh,
    required this.criticalHigh,
    required this.axisMax,
    required this.unitLabel,
  });

  final double axisMin;
  final double criticalLow;
  final double normalLow;
  final double normalHigh;
  final double criticalHigh;
  final double axisMax;
  final String unitLabel;
}

/// Returns the canonical safe range for a given vital type. For blood
/// pressure this returns the **systolic** range (the dominant indicator);
/// the diastolic value is shown alongside but not gauged separately.
VitalSafeRange? vitalSafeRangeFor(String vitalType, {ThresholdConfig? config}) {
  final t = config ?? ThresholdService.instance.config;
  switch (vitalType) {
    case 'hr':
      return VitalSafeRange(
        axisMin: 30,
        criticalLow: t.heartRate.urgentLow,
        normalLow: t.heartRate.sendLow,
        normalHigh: t.heartRate.watchHigh,
        criticalHigh: t.heartRate.sendHigh,
        axisMax: 160,
        unitLabel: 'bpm',
      );
    case 'spo2':
      return VitalSafeRange(
        axisMin: 80,
        criticalLow: t.spo2.urgentLow,
        normalLow: t.spo2.watchLow,
        normalHigh: 100,
        criticalHigh: 100,
        axisMax: 100,
        unitLabel: '%',
      );
    case 'temp':
      return VitalSafeRange(
        axisMin: 34.0,
        criticalLow: t.bodyTemp.urgentLow,
        normalLow: t.bodyTemp.sendLow,
        normalHigh: t.bodyTemp.watchHigh,
        criticalHigh: t.bodyTemp.sendHigh,
        axisMax: 40.0,
        unitLabel: '°C',
      );
    case 'bp':
      return VitalSafeRange(
        axisMin: 50,
        criticalLow: t.sysBp.urgentLow,
        normalLow: t.sysBp.sendLow,
        normalHigh: t.sysBp.watchHigh,
        criticalHigh: t.sysBp.sendHigh,
        axisMax: 200,
        unitLabel: 'mmHg',
      );
    case 'rr':
      return VitalSafeRange(
        axisMin: 5,
        criticalLow: t.respRate.urgentLow,
        normalLow: 14,
        normalHigh: t.respRate.watchHigh,
        criticalHigh: t.respRate.sendHigh,
        axisMax: 35,
        unitLabel: 'lần/phút',
      );
    default:
      return null;
  }
}

/// Extracts the gauge-relevant numeric value from a string `value`. For
/// blood pressure the input is `"sys/dia"` and we return systolic; for the
/// others the value is parsed directly. Returns `null` on `--` placeholders.
double? extractGaugeValue(String vitalType, String value) {
  if (value.isEmpty || value.startsWith('-')) return null;

  if (vitalType == 'bp') {
    final parts = value.split('/');
    if (parts.isEmpty) return null;
    return double.tryParse(parts.first);
  }
  return double.tryParse(value);
}
