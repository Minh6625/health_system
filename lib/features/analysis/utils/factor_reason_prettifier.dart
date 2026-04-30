/// F-14 (M-1): rewrite raw `feature_key=value` segments inside SHAP/AI
/// "reason" strings into clean Vietnamese.
///
/// Backend (model API) builds reason text via
/// `prediction_contract.py::_build_reason`, which falls through to a
/// raw template `"{feature}={value} đang làm {giảm,tăng} nguy cơ"`
/// for any feature not covered by `REASON_OVERRIDES` AND for every
/// `direction == 'risk_down'` (the override branch only fires on
/// risk_up). Result: tester sees `heart_rate=68.6 đang làm giảm nguy cơ`
/// in the risk-report screens — the literal API contract leaks.
///
/// We patch this on the consumption side rather than the model API
/// because the model API change requires a cross-repo deploy + test
/// migration in `healthguard-model-api/tests/conftest.py`. The
/// frontend prettifier is a single-file change that ships in the next
/// app release. If/when the backend catches up the prettifier becomes
/// a no-op (input strings no longer contain raw keys).
library;

/// Vietnamese display labels + units for the patient-facing features
/// the model emits. Keys mirror the canonical `feature` field returned
/// by the model API (`heart_rate`, `spo2`, `blood_pressure_sys`...).
///
/// Reason strings are produced upstream as `"{feature}={value} ..."` —
/// we replace the `{feature}={value}` segment with `"{Label} {value} {unit}"`
/// so the rest of the sentence ("đang làm giảm nguy cơ") flows naturally.
const Map<String, _FactorLabel> _factorLabels = <String, _FactorLabel>{
  'heart_rate': _FactorLabel('Nhịp tim', 'BPM'),
  'spo2': _FactorLabel('SpO₂', '%'),
  'body_temperature': _FactorLabel('Nhiệt độ cơ thể', '°C'),
  'temperature': _FactorLabel('Nhiệt độ', '°C'),
  'systolic_blood_pressure': _FactorLabel('Huyết áp tâm thu', 'mmHg'),
  'diastolic_blood_pressure': _FactorLabel('Huyết áp tâm trương', 'mmHg'),
  'blood_pressure_sys': _FactorLabel('Huyết áp tâm thu', 'mmHg'),
  'blood_pressure_dia': _FactorLabel('Huyết áp tâm trương', 'mmHg'),
  'respiratory_rate': _FactorLabel('Nhịp thở', 'lần/phút'),
  'derived_pulse_pressure': _FactorLabel('Áp lực mạch', 'mmHg'),
  'derived_map': _FactorLabel('Huyết áp trung bình', 'mmHg'),
  'derived_hrv': _FactorLabel('Biến thiên nhịp tim', 'ms'),
  // Sleep-domain features (used when sleep risk reports are surfaced
  // through the same screens). Keep the unit blank where the model
  // emits a unitless score so we don't fabricate a "%".
  'sleep_efficiency_pct': _FactorLabel('Hiệu suất giấc ngủ', '%'),
  'sleep_stage_deep_pct': _FactorLabel('Tỉ lệ ngủ sâu', '%'),
  'wake_after_sleep_onset_minutes':
      _FactorLabel('Thời gian thức giữa giấc', 'phút'),
  'stress_score': _FactorLabel('Điểm stress', ''),
};

class _FactorLabel {
  const _FactorLabel(this.label, this.unit);
  final String label;
  final String unit;
}

/// Matches one `feature_key=value` token at the start of a reason
/// string. We anchor with `\b` rather than `^` because the backend
/// occasionally emits compound reasons where the same template is
/// concatenated (e.g. risk_quick_explanation_card joins two reasons
/// with `'; '`); each segment then starts with its own raw token.
final RegExp _featureValueToken = RegExp(
  r'\b([a-z][a-z0-9_]*?)=(-?\d+(?:\.\d+)?)',
  caseSensitive: false,
);

/// Replaces every `feature_key=value` occurrence in [reason] with the
/// Vietnamese label + value + unit looked up in `_factorLabels`.
///
/// Idempotent: running the prettifier on an already-clean string is a
/// no-op because the regex requires the literal `=` separator.
///
/// Falls back to a snake_case → Title Case prettifier for unknown
/// keys so we never re-emit the raw `key=value` form. Numeric values
/// are passed through verbatim (the model already trims trailing
/// zeros via `_reason_value`).
String prettifyFactorReason(String reason) {
  if (reason.isEmpty) return reason;
  return reason.replaceAllMapped(_featureValueToken, (match) {
    final key = match.group(1)!.toLowerCase();
    final value = match.group(2)!;
    final mapped = _factorLabels[key];
    if (mapped != null) {
      final unit = mapped.unit.isEmpty ? '' : ' ${mapped.unit}';
      return '${mapped.label} $value$unit';
    }
    // Unknown feature — at least drop the `=` so the user does not see
    // the API contract leaking. Title-case the snake_case key so it
    // reads like a label, not a column name.
    final pretty = key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
    return '$pretty $value';
  });
}
