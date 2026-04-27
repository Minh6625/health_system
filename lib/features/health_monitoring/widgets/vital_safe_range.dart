/// Numeric thresholds used by [VitalSafeRangeBar] to draw the 5-zone gauge.
///
/// Zones (left → right):
/// 1. critical-low     [axisMin .. criticalLow)
/// 2. warning-low      [criticalLow .. normalLow)
/// 3. normal           [normalLow .. normalHigh]
/// 4. warning-high     (normalHigh .. criticalHigh]
/// 5. critical-high    (criticalHigh .. axisMax]
///
/// All thresholds are mirrored from `vital_signs.dart` classifiers so the
/// gauge always agrees with the colored status pill.
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
VitalSafeRange? vitalSafeRangeFor(String vitalType) {
  switch (vitalType) {
    case 'hr':
      // <50 critical, 50-59 warn, 60-100 normal, 101-120 warn, >120 critical.
      return const VitalSafeRange(
        axisMin: 30,
        criticalLow: 50,
        normalLow: 60,
        normalHigh: 100,
        criticalHigh: 120,
        axisMax: 160,
        unitLabel: 'bpm',
      );
    case 'spo2':
      // <92 critical, 92-94 warn, ≥95 normal. No upper warning.
      return const VitalSafeRange(
        axisMin: 80,
        criticalLow: 92,
        normalLow: 95,
        normalHigh: 100,
        criticalHigh: 100,
        axisMax: 100,
        unitLabel: '%',
      );
    case 'temp':
      // <35.5 critical, 35.5-36.0 warn, 36.1-37.2 normal,
      // 37.3-37.7 warn, ≥37.8 critical.
      return const VitalSafeRange(
        axisMin: 34.0,
        criticalLow: 35.5,
        normalLow: 36.1,
        normalHigh: 37.2,
        criticalHigh: 37.8,
        axisMax: 40.0,
        unitLabel: '°C',
      );
    case 'bp':
      // Systolic: <70 critical, 70-89 warn, 90-120 normal,
      // 121-139 warn, ≥140 critical.
      return const VitalSafeRange(
        axisMin: 50,
        criticalLow: 70,
        normalLow: 90,
        normalHigh: 120,
        criticalHigh: 140,
        axisMax: 200,
        unitLabel: 'mmHg',
      );
    case 'rr':
      // <12 critical, 12-13 warn, 14-20 normal, 21-25 warn, >25 critical.
      return const VitalSafeRange(
        axisMin: 5,
        criticalLow: 12,
        normalLow: 14,
        normalHigh: 20,
        criticalHigh: 25,
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
