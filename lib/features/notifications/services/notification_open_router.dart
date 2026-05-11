import 'dart:convert';

import '../models/notification_open_target.dart';

String? normalizeNotificationRiskLevel(String? level) {
  switch (level?.trim().toLowerCase()) {
    case 'low':
      return 'low';
    case 'medium':
    case 'moderate':
    case 'high':
      return 'medium';
    case 'critical':
      return 'critical';
    default:
      return null;
  }
}

String resolveNotificationRiskLevel(
  String? rawLevel, {
  required String alertType,
}) {
  final normalized = normalizeNotificationRiskLevel(rawLevel);
  if (normalized != null) {
    return normalized;
  }

  switch (alertType.trim().toLowerCase()) {
    case 'risk_critical':
      return 'critical';
    case 'risk_low':
      return 'low';
    case 'risk_medium':
    case 'risk_high':
    default:
      return 'medium';
  }
}

NotificationOpenTarget? parseNotificationOpenTarget(
  Map<String, dynamic> rawData,
) {
  if (rawData.isEmpty) {
    return null;
  }

  final data = rawData.map(
    (String key, dynamic value) => MapEntry(key.toString(), value),
  );
  final rawType = (data['type'] ?? '').toString().trim().toLowerCase();
  final alertType = (data['alert_type'] ?? data['alertType'] ?? '')
      .toString()
      .trim()
      .toLowerCase();

  final isRisk =
      rawType == 'risk' ||
      rawType == 'risk_alert' ||
      alertType.startsWith('risk_');

  if (isRisk) {
    final notificationId =
        (data['notification_id'] ?? data['notificationId'] ?? data['id'])
            ?.toString()
            .trim();
    if (notificationId == null || notificationId.isEmpty) {
      return null;
    }

    return NotificationOpenTarget(
      type: 'risk',
      notificationId: notificationId,
      alertType: alertType.isEmpty ? 'risk_high' : alertType,
      riskLevel: resolveNotificationRiskLevel(
        (data['risk_level'] ?? data['riskLevel'])?.toString(),
        alertType: alertType.isEmpty ? 'risk_high' : alertType,
      ),
      riskScoreId: int.tryParse(
        (data['risk_score_id'] ?? data['riskScoreId'] ?? '').toString(),
      ),
      title: data['title']?.toString(),
      message: (data['body'] ?? data['message'])?.toString(),
    );
  }

  // Module FA-2: fall pushes don't carry a sos_id — they use
  // ``fall_event_id``/``fall_event_uuid``.  Fall back to fall_event_id
  // as the subject id so the existing SOS-style payload + dedup
  // pipeline runs unchanged; the runtime distinguishes fall vs SOS by
  // inspecting the ``alertType`` field on the resulting target before
  // navigating to FallAlertScreen instead of SosDetailScreen.
  final fallEventId = (data['fall_event_id'] ?? data['fallEventId'])
      ?.toString()
      .trim();
  final sosId =
      (data['sos_id'] ??
              data['sos_event_id'] ??
              data['event_id'] ??
              data['sosId'])
          ?.toString()
          .trim();
  final isFall =
      rawType == 'fall_alert' ||
      alertType == 'fall_detected' ||
      alertType == 'fall_detection';

  final subjectId =
      (sosId?.isNotEmpty ?? false)
          ? sosId!
          : (isFall && (fallEventId?.isNotEmpty ?? false))
          ? fallEventId!
          : null;
  if (subjectId == null || subjectId.isEmpty) {
    return null;
  }

  return NotificationOpenTarget(
    type: 'sos',
    sosId: subjectId,
    alertType: isFall ? 'fall_detected' : (alertType.isEmpty ? null : alertType),
    title: data['title']?.toString(),
    message: (data['body'] ?? data['message'])?.toString(),
  );
}

Map<String, dynamic>? buildNotificationAndroidCriticalRiskLaunchPayload(
  Map<String, dynamic> rawData, {
  String? fallbackTitle,
  String? fallbackBody,
}) {
  final target = parseNotificationOpenTarget(rawData);
  final notificationId = target?.notificationId?.trim();
  if (target == null ||
      target.type != 'risk' ||
      target.riskLevel != 'critical' ||
      notificationId == null ||
      notificationId.isEmpty) {
    return null;
  }

  final title = (target.title?.trim().isNotEmpty ?? false)
      ? target.title!.trim()
      : (fallbackTitle?.trim().isNotEmpty ?? false)
      ? fallbackTitle!.trim()
      : '🚨 Cảnh báo sức khỏe khẩn cấp';
  final body = (target.message?.trim().isNotEmpty ?? false)
      ? target.message!.trim()
      : (fallbackBody?.trim().isNotEmpty ?? false)
      ? fallbackBody!.trim()
      : 'Phát hiện chỉ số sức khỏe nguy hiểm. Cần kiểm tra ngay.';

  return <String, dynamic>{
    'type': 'risk',
    'notificationId': notificationId,
    'notification_id': notificationId,
    'alertType': target.alertType ?? 'risk_critical',
    'alert_type': target.alertType ?? 'risk_critical',
    'riskLevel': 'critical',
    'risk_level': 'critical',
    if (target.riskScoreId != null) 'riskScoreId': target.riskScoreId,
    if (target.riskScoreId != null) 'risk_score_id': target.riskScoreId,
    'title': title,
    'body': body,
    'message': body,
  };
}

/// Build a launch-payload map for SOS / fall_detected emergencies (P1 #5).
///
/// Mirrors [buildNotificationAndroidCriticalRiskLaunchPayload] for the SOS
/// channel: when the backend sends a data-only emergency push, the Flutter
/// background handler turns it into a local fullScreenIntent notification on
/// the ``sos_fullscreen_alerts`` channel using this payload.
Map<String, dynamic>? buildNotificationAndroidSosLaunchPayload(
  Map<String, dynamic> rawData, {
  String? fallbackTitle,
  String? fallbackBody,
}) {
  final target = parseNotificationOpenTarget(rawData);
  if (target == null || target.type != 'sos') {
    return null;
  }
  final sosId = target.sosId?.trim();
  if (sosId == null || sosId.isEmpty) {
    return null;
  }

  final data = rawData.map(
    (String key, dynamic value) => MapEntry(key.toString(), value),
  );
  final rawType = (data['type'] ?? '').toString().trim().toLowerCase();
  final alertType = (data['alert_type'] ?? data['alertType'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final triggerType = (data['trigger_type'] ?? data['triggerType'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final notificationId =
      (data['notification_id'] ?? data['notificationId'])?.toString().trim();
  final fallEventId =
      (data['fall_event_id'] ?? data['fallEventId'])?.toString().trim();
  final fallEventUuid =
      (data['fall_event_uuid'] ?? data['fallEventUuid'])?.toString().trim();

  final isFall =
      rawType == 'fall_alert' ||
      alertType == 'fall_detected' ||
      alertType == 'fall_detection' ||
      triggerType == 'fall_detected' ||
      triggerType == 'fall_detection';

  final title = (target.title?.trim().isNotEmpty ?? false)
      ? target.title!.trim()
      : (fallbackTitle?.trim().isNotEmpty ?? false)
      ? fallbackTitle!.trim()
      : (isFall ? '🚨 Phát hiện té ngã' : '🚨 Cảnh báo SOS khẩn cấp');
  final body = (target.message?.trim().isNotEmpty ?? false)
      ? target.message!.trim()
      : (fallbackBody?.trim().isNotEmpty ?? false)
      ? fallbackBody!.trim()
      : (isFall
            ? 'Phát hiện sự kiện té ngã. Cần kiểm tra ngay.'
            : 'Có cảnh báo SOS khẩn cấp mới.');

  return <String, dynamic>{
    // Keep ``type='sos'`` so the existing tap-handler (openSosDetail) is
    // wired by default.  ``alertType`` discriminates fall vs SOS for any
    // tap-routing logic that wants to deep-link into FallAlertScreen.
    'type': 'sos',
    'sosId': sosId,
    'sos_id': sosId,
    'sos_event_id': sosId,
    if (notificationId != null && notificationId.isNotEmpty) 'notificationId':
        notificationId,
    if (notificationId != null && notificationId.isNotEmpty) 'notification_id':
        notificationId,
    if (alertType.isNotEmpty) 'alertType': alertType,
    if (alertType.isNotEmpty) 'alert_type': alertType,
    if (triggerType.isNotEmpty) 'triggerType': triggerType,
    if (triggerType.isNotEmpty) 'trigger_type': triggerType,
    if (isFall && fallEventId != null && fallEventId.isNotEmpty)
      'fall_event_id': fallEventId,
    if (isFall && fallEventUuid != null && fallEventUuid.isNotEmpty)
      'fall_event_uuid': fallEventUuid,
    'title': title,
    'body': body,
    'message': body,
  };
}

NotificationOpenTarget? parseNotificationAndroidCriticalRiskLaunchPayload(
  dynamic rawPayload,
) {
  Map<String, dynamic>? decoded;

  if (rawPayload is String) {
    final normalized = rawPayload.trim();
    if (normalized.isEmpty) {
      return null;
    }

    try {
      final value = jsonDecode(normalized);
      if (value is Map) {
        decoded = value.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
  } else if (rawPayload is Map) {
    decoded = rawPayload.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }

  if (decoded == null) {
    return null;
  }

  final target = parseNotificationOpenTarget(decoded);
  final notificationId = target?.notificationId?.trim();
  if (target == null ||
      target.type != 'risk' ||
      target.riskLevel != 'critical' ||
      notificationId == null ||
      notificationId.isEmpty) {
    return null;
  }

  return target;
}
