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

/// True when the alert is a fall detection (Module FA-2).  Mirrors
/// the discriminators set by the backend's ``send_fall_critical_alert``
/// helper: ``alert_type='fall_detected'`` or ``data.type='fall_alert'``.
bool isFallAlertType(String alertType) {
  final normalized = alertType.trim().toLowerCase();
  return normalized == 'fall_detected' || normalized == 'fall_detection';
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
    // Module FA-2: fall pushes carry ``fall_event_id`` instead of
    // ``sos_id``; fall back to it so ``_isEmergencyAlert`` accepts the
    // push and the foreground pipeline runs the fullscreen presenter.
    item['fall_event_id'],
    data['fall_event_id'],
    data['fallEventId'],
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
  // Module FA-2: fall pushes carry ``fall_event_id`` instead of
  // ``sos_id``.  We let the fall path borrow the SOS subjectId slot so
  // the foreground dedup + presentation pipeline runs unchanged; the
  // adapter (presentFullscreenAlert) inspects alert_type / data.type
  // separately to decide whether to deep-link to FallAlertScreen vs
  // SosDetailScreen.
  final fallEventId = data['fall_event_id']?.toString().trim();
  final isFall = isFallAlertType(alertType);
  final notificationId = (data['notification_id'] ?? data['id'])
      ?.toString()
      .trim();

  final String? effectiveId;
  if (isRisk) {
    effectiveId = (notificationId?.isNotEmpty ?? false)
        ? notificationId!
        : null;
  } else if (isFall) {
    effectiveId = (fallEventId?.isNotEmpty ?? false)
        ? fallEventId!
        : (sosId?.isNotEmpty ?? false) ? sosId! : null;
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
    id: (notificationId?.isNotEmpty ?? false)
        ? notificationId!
        : '$alertType-$effectiveId',
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
      // Module FA-2: keep the fall_event_id around so the adapter can
      // open FallAlertScreen instead of SosDetailScreen when the user
      // taps the foreground notification.
      if (isFall && fallEventId != null && fallEventId.isNotEmpty)
        'fall_event_id': fallEventId,
      if (isFall && data['fall_event_uuid'] != null)
        'fall_event_uuid': data['fall_event_uuid'].toString(),
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
