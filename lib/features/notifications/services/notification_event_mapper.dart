import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/notification_event.dart';
import 'notification_open_router.dart';

bool isRiskAlertType(String alertType) {
  return alertType.trim().toLowerCase().startsWith('risk_');
}

bool isActionableNotificationType(String alertType) {
  final normalized = alertType.trim().toLowerCase();
  return normalized == 'sos' ||
      normalized == 'manual' ||
      normalized.contains('sos') ||
      normalized == 'fall_detected' ||
      normalized == 'fall_detection' ||
      isRiskAlertType(normalized);
}

String? extractNotificationSubjectId(Map<String, dynamic> item) {
  final data = _toMap(item['data']);
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
    if (candidate == null) {
      continue;
    }
    final value = candidate.toString().trim();
    if (value.isNotEmpty) {
      return value;
    }
  }

  final alertType = (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
  if (isRiskAlertType(alertType)) {
    final fallbackId =
        (data['notification_id'] ?? item['notification_id'] ?? item['id'])
            ?.toString()
            .trim();
    if (fallbackId != null && fallbackId.isNotEmpty) {
      return fallbackId;
    }
  }

  return null;
}

NotificationEvent? mapNotificationEventFromPushData(
  Map<String, dynamic> rawData, {
  RemoteMessage? message,
}) {
  final data = rawData.map(
    (String key, dynamic value) => MapEntry(key.toString(), value),
  );

  final alertType = (data['alert_type'] ?? data['trigger_type'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (alertType.isEmpty || !isActionableNotificationType(alertType)) {
    return null;
  }

  final isRisk = isRiskAlertType(alertType);
  final riskLevel = isRisk
      ? resolveNotificationRiskLevel(
          data['risk_level']?.toString(),
          alertType: alertType,
        )
      : null;

  final sosId = (data['sos_id'] ?? data['sos_event_id'] ?? data['event_id'])
      ?.toString()
      .trim();
  final notificationId = (data['notification_id'] ?? data['id'])
      ?.toString()
      .trim();

  final String? effectiveId;
  if (isRisk) {
    effectiveId = (notificationId?.isNotEmpty ?? false)
        ? notificationId!
        : null;
  } else {
    effectiveId = (sosId?.isNotEmpty ?? false) ? sosId! : null;
  }
  if (effectiveId == null || effectiveId.isEmpty) {
    return null;
  }

  final title = _resolveTitle(
    message: message,
    data: data,
    isRisk: isRisk,
    riskLevel: riskLevel,
  );
  final body = _resolveBody(message: message, data: data, isRisk: isRisk);

  return NotificationEvent(
    id: notificationId ?? '$alertType-$effectiveId',
    alertType: alertType,
    severity: isRisk ? riskLevel ?? 'medium' : 'critical',
    title: title,
    message: body,
    createdAt:
        DateTime.tryParse(data['created_at']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    isRead: false,
    data: <String, dynamic>{
      if (sosId != null && sosId.isNotEmpty) 'sos_id': sosId,
      if (sosId != null && sosId.isNotEmpty) 'sos_event_id': sosId,
      if (data['event_id'] != null) 'event_id': data['event_id'],
      if (data['trigger_type'] != null) 'trigger_type': data['trigger_type'],
      if (isRisk) 'risk_level': riskLevel ?? 'medium',
      if (isRisk && notificationId != null) 'notification_id': notificationId,
      if (isRisk && data['risk_score_id'] != null)
        'risk_score_id': data['risk_score_id'].toString(),
    },
  );
}

String _resolveTitle({
  required RemoteMessage? message,
  required Map<String, dynamic> data,
  required bool isRisk,
  required String? riskLevel,
}) {
  final fromPush = message?.notification?.title ?? data['title']?.toString();
  if (fromPush != null && fromPush.trim().isNotEmpty) {
    return fromPush.trim();
  }
  if (isRisk) {
    return riskLevel == 'critical'
        ? '🚨 Cảnh báo sức khỏe khẩn cấp'
        : '⚠️ Cảnh báo sức khỏe';
  }
  return 'Cảnh báo SOS';
}

String _resolveBody({
  required RemoteMessage? message,
  required Map<String, dynamic> data,
  required bool isRisk,
}) {
  final fromPush =
      message?.notification?.body ??
      data['body']?.toString() ??
      data['message']?.toString();
  if (fromPush != null && fromPush.trim().isNotEmpty) {
    return fromPush.trim();
  }
  if (isRisk) {
    return 'Phát hiện chỉ số sức khỏe bất thường. Nhấn để xem.';
  }
  return 'Có cảnh báo khẩn cấp mới';
}

Map<String, dynamic> _toMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) => MapEntry(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}
