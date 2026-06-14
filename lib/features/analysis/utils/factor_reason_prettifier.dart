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

/// Verb-suffix rewrites for old cached DB records that were persisted
/// while Gemini was unavailable and the no-diacritic fallback fired.
/// Keys are exact ASCII substrings; values are their proper Vietnamese.
/// Applied after the regex pass so we don't interfere with `=`-detection.
const Map<String, String> _verbRewrites = {
  ' dang lam tang nguy co': ' đang làm tăng nguy cơ',
  ' dang lam giam nguy co': ' đang làm giảm nguy cơ',
  ' dang lam tang muc do canh bao': ' đang làm tăng mức độ cảnh báo',
  ' la cac tin hieu dang duoc model uu tien theo doi': ' là các tín hiệu đang được model ưu tiên theo dõi',
  ' dang keo sleep score xuong': ' đang kéo điểm giấc ngủ xuống',
  ' dang ho tro sleep score on dinh hon': ' đang hỗ trợ điểm giấc ngủ ổn định hơn',
};

/// Exact-match rewrites for old ``recommended_actions`` strings persisted
/// by the no-diacritic fallback.  Keys are the ASCII originals; values are
/// proper Vietnamese.  Passthrough for anything not in this map.
const Map<String, String> _actionRewrites = {
  'do lai chi so': 'Đo lại chỉ số',
  'doi chieu trieu chung': 'Đối chiếu triệu chứng',
  'lien he nhan vien y te': 'Liên hệ nhân viên y tế',
  'theo doi them 30-60 phut': 'Theo dõi thêm 30-60 phút',
  'tiep tuc theo doi dinh ky': 'Tiếp tục theo dõi định kỳ',
  'duy tri routine do': 'Duy trì thói quen đo',
  'kiem tra an toan ngay': 'Kiểm tra an toàn ngay',
  'xac minh voi nguoi dung': 'Xác minh với người dùng',
  'khoi dong quy trinh canh bao': 'Khởi động quy trình cảnh báo',
  'xac minh event': 'Xác minh sự kiện',
  'theo doi them cac cua so lien tiep': 'Theo dõi thêm các cửa sổ liên tiếp',
  'tiep tuc giam sat': 'Tiếp tục giám sát',
  'doi chieu neu co bao dong khac': 'Đối chiếu nếu có báo động khác',
  'xem lai hieu suat ngu': 'Xem lại hiệu suất ngủ',
  'giam stress va screen time truoc khi ngu': 'Giảm stress và screen time trước khi ngủ',
  'doi chieu cac yeu to gay giac': 'Đối chiếu các yếu tố gây giấc',
  'duy tri gio ngu deu': 'Duy trì giờ ngủ đều',
  'theo doi xu huong them vai dem': 'Theo dõi xu hướng thêm vài đêm',
  'duy tri thoi quen ngu deu': 'Duy trì thói quen ngủ đều',
  'tiep tuc theo doi xu huong': 'Tiếp tục theo dõi xu hướng',
};

/// Returns the Vietnamese display label for a raw snake_case feature key.
///
/// Falls back to a Title Case conversion for unknown keys so we never
/// show raw underscored names in the UI. The optional [includeUnit]
/// flag appends the unit in parentheses when true (default false).
String humanizeFeatureName(String featureKey, {bool includeUnit = false}) {
  final mapped = _factorLabels[featureKey.toLowerCase()];
  if (mapped != null) {
    if (includeUnit && mapped.unit.isNotEmpty) {
      return '${mapped.label} (${mapped.unit})';
    }
    return mapped.label;
  }
  return featureKey
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

/// Returns only the unit string for a raw feature key (empty string if unknown).
String featureUnit(String featureKey) {
  return _factorLabels[featureKey.toLowerCase()]?.unit ?? '';
}

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
  String result = reason.replaceAllMapped(_featureValueToken, (match) {
    final key = match.group(1)!.toLowerCase();
    final value = match.group(2)!;
    final mapped = _factorLabels[key];
    if (mapped != null) {
      final unit = mapped.unit.isEmpty ? '' : ' ${mapped.unit}';
      return '${mapped.label} $value$unit';
    }
    final pretty = key
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
    return '$pretty $value';
  });
  for (final entry in _verbRewrites.entries) {
    if (result.contains(entry.key)) {
      result = result.replaceAll(entry.key, entry.value);
    }
  }
  return result;
}

/// Rewrites a single ``recommended_actions`` item from old cached DB
/// records (persisted when Gemini was unavailable) to proper Vietnamese.
///
/// Idempotent: already-correct strings pass through unchanged because
/// they are not in the [_actionRewrites] map keys.
String prettifyRecommendedAction(String action) {
  if (action.isEmpty) return action;
  return _actionRewrites[action.trim()] ?? action;
}
