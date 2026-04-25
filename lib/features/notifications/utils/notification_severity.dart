import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';

/// Pure helpers for notification severity / alert type formatting.
///
/// Extracted from `notifications_screen.dart` (W5 split). All functions are
/// pure: no state, no side effects. Can be used by both the list screen and
/// the detail screen.
String? normalizeNotificationSeverityLabel(String? severity) {
  switch (severity?.trim().toLowerCase()) {
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

Color notificationSeverityColor(String? severity) {
  switch (normalizeNotificationSeverityLabel(severity)) {
    case 'critical':
      return AppColors.critical;
    case 'medium':
      return AppColors.warning;
    case 'low':
    default:
      return AppColors.success;
  }
}

String notificationSeverityLabel(String? severity) {
  switch (normalizeNotificationSeverityLabel(severity)) {
    case 'critical':
      return 'critical';
    case 'medium':
      return 'medium';
    case 'low':
      return 'low';
    default:
      return 'low';
  }
}

/// Maps backend `alert_type` strings to Vietnamese display labels.
String notificationAlertTypeLabel(String alertType) {
  switch (alertType.toLowerCase()) {
    case 'fall_detected':
    case 'fall_detection':
      return 'Té ngã';
    case 'manual':
    case 'sos':
      return 'Khẩn cấp';
    case 'risk_critical':
      return 'Nguy cơ nghiêm trọng';
    case 'risk_high':
      return 'Cảnh báo nguy cơ';
    case 'medication_missed':
      return 'Quên thuốc';
    case 'heart_rate_critical':
    case 'spo2_critical':
    case 'blood_pressure_critical':
    case 'vital_critical':
      return 'Chỉ số nguy hiểm';
    default:
      return 'Hệ thống';
  }
}

/// Background color for alert-type chips in the list view.
Color notificationTypeChipColor(String alertType) {
  switch (alertType.toLowerCase()) {
    case 'fall_detected':
    case 'fall_detection':
      return AppStateColors.criticalBg;
    case 'manual':
    case 'sos':
      return AppStateColors.warningBg;
    case 'risk_critical':
      return AppStateColors.criticalBg;
    case 'risk_high':
      return AppStateColors.warningBg;
    case 'medication_missed':
      return AppStateColors.successBg;
    default:
      return AppStateColors.infoBg;
  }
}

/// True if the notification represents an SOS / manual emergency event.
bool isSosNotification(Map<String, dynamic> item) {
  final alertType = (item['alert_type'] as String?)?.toLowerCase() ?? '';
  final title = (item['title'] as String?)?.toLowerCase() ?? '';
  return alertType == 'sos' ||
      alertType == 'manual' ||
      alertType.contains('sos') ||
      title.contains('sos');
}

/// True if the notification belongs to the risk-escalation family
/// (`risk_high`, `risk_critical`, ...).
bool isRiskNotification(Map<String, dynamic> item) {
  final alertType = (item['alert_type'] as String?)?.toLowerCase() ?? '';
  return alertType.startsWith('risk_');
}

/// Sort priority used by [NotificationsScreen]: lower = higher priority.
/// SOS first, then risk, then everything else.
int notificationPriority(Map<String, dynamic> item) {
  if (isSosNotification(item)) return 0;
  if (isRiskNotification(item)) return 1;
  return 2;
}

/// Parses `created_at` ISO string from a notification map.
DateTime? notificationCreatedAt(Map<String, dynamic> item) {
  final raw = item['created_at'] as String?;
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

/// Vietnamese "x phút trước" / "x giờ trước" / "x ngày trước" label.
String notificationTimeAgoLabel(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  return '${diff.inDays} ngày trước';
}

/// `dd/MM/yyyy HH:mm` format for created_at / read_at timestamps.
String notificationDateTimeLabel(DateTime createdAt) {
  final day = createdAt.day.toString().padLeft(2, '0');
  final month = createdAt.month.toString().padLeft(2, '0');
  final year = createdAt.year.toString();
  final hour = createdAt.hour.toString().padLeft(2, '0');
  final minute = createdAt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

/// Sorts notifications by: unread above read, then SOS > risk > others,
/// then newest first. Pure (does not mutate `source`).
List<Map<String, dynamic>> sortNotifications(
  List<Map<String, dynamic>> source,
) {
  final sorted = List<Map<String, dynamic>>.from(source);
  sorted.sort((a, b) {
    final aIsRead = a['is_read'] == true;
    final bIsRead = b['is_read'] == true;
    if (aIsRead != bIsRead) {
      return aIsRead ? 1 : -1;
    }

    final aPriority = notificationPriority(a);
    final bPriority = notificationPriority(b);
    if (aPriority != bPriority) {
      return aPriority.compareTo(bPriority);
    }

    final aCreated = notificationCreatedAt(a);
    final bCreated = notificationCreatedAt(b);
    if (aCreated == null && bCreated == null) {
      return 0;
    }
    if (aCreated == null) {
      return 1;
    }
    if (bCreated == null) {
      return -1;
    }
    return bCreated.compareTo(aCreated);
  });
  return sorted;
}
