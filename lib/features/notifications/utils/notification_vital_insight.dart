import 'package:flutter/material.dart';

/// State for a single vital reading attached to a notification.
enum NotificationVitalState { normal, warning, critical }

/// Snapshot of the dominant vital reading reported by a notification.
///
/// Built lazily by [buildNotificationVitalInsight] from the notification's
/// `data` map. Used by the detail screen's "Diễn biến chỉ số" section.
class NotificationVitalInsight {
  const NotificationVitalInsight({
    required this.metricLabel,
    required this.valueText,
    required this.statusLabel,
    required this.state,
    required this.icon,
    this.trendText,
  });

  final String metricLabel;
  final String valueText;
  final String statusLabel;
  final NotificationVitalState state;
  final IconData icon;
  final String? trendText;
}

/// Convert any `Map`-like data field into a `Map<String, dynamic>` safely.
Map<String, dynamic> toNotificationDataMap(Object? rawData) {
  if (rawData is Map<String, dynamic>) {
    return rawData;
  }
  if (rawData is Map) {
    return rawData.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

bool _containsAny(String source, List<String> keywords) {
  for (final keyword in keywords) {
    if (source.contains(keyword)) {
      return true;
    }
  }
  return false;
}

double? _asDouble(Object? raw) {
  if (raw == null) {
    return null;
  }
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse(raw.toString());
}

String _formatNumber(double value, {int maxFraction = 1}) {
  final isInt = value % 1 == 0;
  return value.toStringAsFixed(isInt ? 0 : maxFraction);
}

NotificationVitalState _heartRateState(double value) {
  if (value < 50 || value > 120) return NotificationVitalState.critical;
  if (value < 60 || value > 100) return NotificationVitalState.warning;
  return NotificationVitalState.normal;
}

NotificationVitalState _spo2State(double value) {
  if (value < 90) return NotificationVitalState.critical;
  if (value < 95) return NotificationVitalState.warning;
  return NotificationVitalState.normal;
}

NotificationVitalState _bloodPressureState(double? sys, double? dia) {
  final sysCritical = sys != null && (sys >= 180 || sys < 80);
  final diaCritical = dia != null && (dia >= 120 || dia < 50);
  if (sysCritical || diaCritical) return NotificationVitalState.critical;

  final sysWarning = sys != null && (sys >= 140 || sys < 90);
  final diaWarning = dia != null && (dia >= 90 || dia < 60);
  if (sysWarning || diaWarning) return NotificationVitalState.warning;
  return NotificationVitalState.normal;
}

NotificationVitalState _temperatureState(double value) {
  if (value >= 39 || value < 35) return NotificationVitalState.critical;
  if (value >= 37.5 || value < 36) return NotificationVitalState.warning;
  return NotificationVitalState.normal;
}

String _stateLabel(NotificationVitalState state) {
  return switch (state) {
    NotificationVitalState.normal => 'Bình thường',
    NotificationVitalState.warning => 'Cảnh báo',
    NotificationVitalState.critical => 'Nguy cấp',
  };
}

/// Returns a [NotificationVitalInsight] if the notification carries a
/// recognisable vital reading (heart rate / SpO2 / blood pressure /
/// temperature), or `null` otherwise.
NotificationVitalInsight? buildNotificationVitalInsight(
  Map<String, dynamic> item,
) {
  final data = toNotificationDataMap(item['data']);
  final title = ((item['title'] as String?) ?? '').toLowerCase();
  final message = ((item['message'] as String?) ?? '').toLowerCase();
  final alertType = ((item['alert_type'] as String?) ?? '').toLowerCase();

  final text = '$title $message $alertType';
  final hasVitalKey =
      data.containsKey('heart_rate') ||
      data.containsKey('spo2') ||
      data.containsKey('blood_pressure_sys') ||
      data.containsKey('blood_pressure_dia') ||
      data.containsKey('temperature');

  final isVitalNotification =
      hasVitalKey ||
      _containsAny(text, [
        'nhịp tim',
        'heart rate',
        'spo2',
        'huyết áp',
        'nhiệt độ',
        'vital',
      ]);

  if (!isVitalNotification) {
    return null;
  }

  final hasHeartRate =
      data.containsKey('heart_rate') ||
      _containsAny(text, ['nhịp tim', 'heart rate']);
  if (hasHeartRate) {
    final current = _asDouble(data['heart_rate']);
    if (current == null) return null;

    final state = _heartRateState(current);
    String? trendText;
    if (current > 100) {
      final from = _asDouble(data['threshold']) ?? 100;
      trendText =
          'Tăng từ ${_formatNumber(from, maxFraction: 0)} BPM lên ${_formatNumber(current, maxFraction: 0)} BPM';
    } else if (current < 60) {
      final from = _asDouble(data['threshold_low']) ?? 60;
      trendText =
          'Giảm từ ${_formatNumber(from, maxFraction: 0)} BPM xuống ${_formatNumber(current, maxFraction: 0)} BPM';
    }

    return NotificationVitalInsight(
      metricLabel: 'Nhịp tim',
      valueText: '${_formatNumber(current, maxFraction: 0)} BPM',
      statusLabel: _stateLabel(state),
      state: state,
      icon: Icons.favorite_rounded,
      trendText: trendText,
    );
  }

  final hasSpo2 = data.containsKey('spo2') || text.contains('spo2');
  if (hasSpo2) {
    final current = _asDouble(data['spo2']);
    if (current == null) return null;

    final state = _spo2State(current);
    String? trendText;
    if (current < 95) {
      final from = _asDouble(data['threshold']) ?? 95;
      trendText =
          'Giảm từ ${_formatNumber(from)}% xuống ${_formatNumber(current)}%';
    }

    return NotificationVitalInsight(
      metricLabel: 'SpO2',
      valueText: '${_formatNumber(current)}%',
      statusLabel: _stateLabel(state),
      state: state,
      icon: Icons.water_drop_rounded,
      trendText: trendText,
    );
  }

  final hasBloodPressure =
      data.containsKey('blood_pressure_sys') ||
      data.containsKey('blood_pressure_dia') ||
      _containsAny(text, ['huyết áp', 'blood pressure']);
  if (hasBloodPressure) {
    final sys = _asDouble(data['blood_pressure_sys']);
    final dia = _asDouble(data['blood_pressure_dia']);
    if (sys == null && dia == null) return null;

    final state = _bloodPressureState(sys, dia);
    final sysText = sys != null ? _formatNumber(sys, maxFraction: 0) : '--';
    final diaText = dia != null ? _formatNumber(dia, maxFraction: 0) : '--';
    String? trendText;

    final isIncrease = (sys != null && sys >= 140) || (dia != null && dia >= 90);
    final isDecrease = (sys != null && sys < 90) || (dia != null && dia < 60);
    if (isIncrease) {
      final fromSys = _asDouble(data['threshold_sys']) ?? 140;
      final fromDia = _asDouble(data['threshold_dia']) ?? 90;
      trendText =
          'Tăng từ ${_formatNumber(fromSys, maxFraction: 0)}/${_formatNumber(fromDia, maxFraction: 0)} mmHg lên $sysText/$diaText mmHg';
    } else if (isDecrease) {
      final fromSys = _asDouble(data['threshold_sys_low']) ?? 90;
      final fromDia = _asDouble(data['threshold_dia_low']) ?? 60;
      trendText =
          'Giảm từ ${_formatNumber(fromSys, maxFraction: 0)}/${_formatNumber(fromDia, maxFraction: 0)} mmHg xuống $sysText/$diaText mmHg';
    }

    return NotificationVitalInsight(
      metricLabel: 'Huyết áp',
      valueText: '$sysText/$diaText mmHg',
      statusLabel: _stateLabel(state),
      state: state,
      icon: Icons.monitor_heart_rounded,
      trendText: trendText,
    );
  }

  final hasTemperature =
      data.containsKey('temperature') ||
      _containsAny(text, ['nhiệt độ', 'temperature', 'temp']);
  if (hasTemperature) {
    final current = _asDouble(data['temperature']);
    if (current == null) return null;

    final state = _temperatureState(current);
    String? trendText;
    if (current >= 37.5) {
      final from = _asDouble(data['threshold']) ?? 37.5;
      trendText =
          'Tăng từ ${_formatNumber(from)}°C lên ${_formatNumber(current)}°C';
    } else if (current < 36) {
      final from = _asDouble(data['threshold_low']) ?? 36;
      trendText =
          'Giảm từ ${_formatNumber(from)}°C xuống ${_formatNumber(current)}°C';
    }

    return NotificationVitalInsight(
      metricLabel: 'Nhiệt độ',
      valueText: '${_formatNumber(current)}°C',
      statusLabel: _stateLabel(state),
      state: state,
      icon: Icons.thermostat_rounded,
      trendText: trendText,
    );
  }

  return null;
}

/// Extracts a SOS event id from a notification (used to deep-link to
/// EmergencySOSDetailScreen). Returns the first non-empty candidate.
String? extractNotificationSosId(Map<String, dynamic> item) {
  final data = toNotificationDataMap(item['data']);
  final candidates = <Object?>[
    item['sos_id'],
    item['sos_event_id'],
    data['sos_id'],
    data['sos_event_id'],
    data['sosId'],
    data['sosEventId'],
    data['event_id'],
  ];

  for (final candidate in candidates) {
    if (candidate == null) continue;
    final value = candidate.toString().trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _prettifyKey(String key) {
  final normalized = key.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return 'Thông tin';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

// F-13 (M-3): keys that are internal DB FKs / debug fields and must
// never be rendered to the end user. Pre-fix the fall-through branch
// at the bottom of `buildNotificationRelatedFields` was prettifying
// `risk_score_id` → "Risk score id" and showing the raw integer FK to
// the user, which is meaningless and leaked DB schema. Add to this set
// instead of the well-known label list when a field should disappear.
const Set<String> _hiddenNotificationDataKeys = <String>{
  'risk_score_id',
  'alert_id',
  'profile_id',
  'user_id',
  'event_id',
  'notification_id',
  'created_by',
  'updated_by',
};

// F-13 (M-3): map enum-like backend strings to Vietnamese labels for
// the notification detail screen. Tester report showed "medium" /
// "initial" rendered raw alongside the prettified field name; this
// gives those values a Vietnamese form so the UI is self-explanatory
// without forcing the user to learn the API contract.
String _localizeRiskLevel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'low':
      return 'Nhẹ';
    case 'medium':
    case 'moderate':
      return 'Trung bình';
    case 'high':
      return 'Cao';
    case 'critical':
      return 'Nguy hiểm';
    default:
      return raw.isEmpty ? '--' : raw;
  }
}

String _localizeEscalationStage(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'initial':
    case 'pending':
      return 'Mới phát sinh';
    case 'escalating':
    case 'in_progress':
      return 'Đang leo thang';
    case 'resolved':
    case 'closed':
      return 'Đã xử lý';
    case 'cancelled':
    case 'canceled':
      return 'Đã hủy';
    default:
      return raw.isEmpty ? '--' : raw;
  }
}

/// Builds the "Chỉ số và thông tin liên quan" rows for the detail screen.
/// Limits to 8 entries, formats common vitals, falls back to prettified
/// key/value for everything else.
List<MapEntry<String, String>> buildNotificationRelatedFields(
  Map<String, dynamic> item,
) {
  final data = toNotificationDataMap(item['data']);
  if (data.isEmpty) {
    return <MapEntry<String, String>>[];
  }

  final fields = <MapEntry<String, String>>[];
  final usedKeys = <String>{};

  void addField(String key, String label, String Function(dynamic)? format) {
    if (!data.containsKey(key)) return;
    final value = data[key];
    if (value == null) return;
    final text = format != null ? format(value) : value.toString();
    if (text.trim().isEmpty) return;
    fields.add(MapEntry(label, text));
    usedKeys.add(key);
  }

  addField('heart_rate', 'Nhịp tim', (v) => '${v.toString()} BPM');
  addField('spo2', 'SpO2', (v) => '${v.toString()}%');
  addField('temperature', 'Nhiệt độ', (v) => '${v.toString()}°C');
  addField('battery', 'Pin thiết bị', (v) => '${v.toString()}%');
  addField('confidence', 'Độ tin cậy', (v) {
    final num? parsed = num.tryParse(v.toString());
    if (parsed == null) return v.toString();
    final pct = parsed <= 1 ? parsed * 100 : parsed;
    return '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%';
  });
  addField('duration_minutes', 'Thời lượng', (v) => '${v.toString()} phút');
  addField('threshold', 'Ngưỡng cảnh báo', (v) => v.toString());
  addField('address', 'Vị trí', (v) => v.toString());
  addField('location', 'Khu vực', (v) => v.toString());
  addField('trigger', 'Kích hoạt bởi', (v) => v.toString());
  addField('offline_duration', 'Mất kết nối', (v) => '${v.toString()} phút');

  // F-13 (M-3): risk-alert specific fields that previously fell through
  // to the snake_case prettifier ("Risk level: medium", "Auto escalate
  // after seconds: 60") — give them proper labels and Vietnamese enum
  // values so the screen reads as a localised UI, not a raw DB dump.
  addField('device_id', 'Thiết bị', (v) => '#${v.toString()}');
  addField(
    'risk_level',
    'Mức nguy cơ',
    (v) => _localizeRiskLevel(v.toString()),
  );
  addField('risk_score', 'Điểm nguy cơ', (v) {
    final num? parsed = num.tryParse(v.toString());
    if (parsed == null) return v.toString();
    return parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 2);
  });
  addField(
    'escalation_stage',
    'Giai đoạn',
    (v) => _localizeEscalationStage(v.toString()),
  );
  addField(
    'auto_escalate_after_seconds',
    'Tự leo thang sau',
    (v) => '${v.toString()} giây',
  );

  final sys = data['blood_pressure_sys'];
  final dia = data['blood_pressure_dia'];
  if (sys != null || dia != null) {
    final sysText = sys?.toString() ?? '--';
    final diaText = dia?.toString() ?? '--';
    fields.add(MapEntry('Huyết áp', '$sysText/$diaText mmHg'));
    usedKeys.add('blood_pressure_sys');
    usedKeys.add('blood_pressure_dia');
  }

  for (final entry in data.entries) {
    if (fields.length >= 8) break;
    if (usedKeys.contains(entry.key)) continue;
    // F-13 (M-3): skip internal FKs like `risk_score_id` so the user
    // does not see meaningless DB row IDs in the detail card.
    if (_hiddenNotificationDataKeys.contains(entry.key)) continue;
    if (entry.value == null || entry.value is Map || entry.value is List) {
      continue;
    }
    fields.add(MapEntry(_prettifyKey(entry.key), entry.value.toString()));
  }

  return fields;
}
