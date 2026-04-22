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

  final sosId =
      (data['sos_id'] ??
              data['sos_event_id'] ??
              data['event_id'] ??
              data['sosId'])
          ?.toString()
          .trim();
  if (sosId == null || sosId.isEmpty) {
    return null;
  }

  return NotificationOpenTarget(
    type: 'sos',
    sosId: sosId,
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
