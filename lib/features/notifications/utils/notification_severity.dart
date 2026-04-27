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

/// Vietnamese label for the severity chip rendered in notification cards
/// and the detail screen. Returns one of 'Nhẹ' / 'Cảnh báo' / 'Nguy hiểm'.
///
/// Previously this helper returned the raw English bucket ('low' / 'medium' /
/// 'critical') which leaked into the UI; callers now display it directly.
String notificationSeverityLabel(String? severity) {
  switch (normalizeNotificationSeverityLabel(severity)) {
    case 'critical':
      return 'Nguy hiểm';
    case 'medium':
      return 'Cảnh báo';
    case 'low':
    default:
      return 'Nhẹ';
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

/// Coarse buckets used by the type filter chips on the notifications
/// screen. The `all` value is reserved for the chip selection state and is
/// never returned by [notificationTypeBucket].
enum NotificationTypeFilter { all, sos, health, medication, system }

/// Returns Vietnamese label for a [NotificationTypeFilter] value, used by
/// the filter chips.
String notificationTypeFilterLabel(NotificationTypeFilter filter) {
  switch (filter) {
    case NotificationTypeFilter.all:
      return 'Tất cả';
    case NotificationTypeFilter.sos:
      return 'Khẩn cấp';
    case NotificationTypeFilter.health:
      return 'Sức khoẻ';
    case NotificationTypeFilter.medication:
      return 'Thuốc';
    case NotificationTypeFilter.system:
      return 'Hệ thống';
  }
}

/// Buckets a notification item by its `alert_type`. Used to power the
/// secondary filter row on the notifications list.
NotificationTypeFilter notificationTypeBucket(Map<String, dynamic> item) {
  final alertType = (item['alert_type'] as String?)?.toLowerCase() ?? '';
  if (alertType == 'sos' ||
      alertType == 'manual' ||
      alertType.startsWith('fall_')) {
    return NotificationTypeFilter.sos;
  }
  if (alertType.startsWith('medication_')) {
    return NotificationTypeFilter.medication;
  }
  if (alertType.startsWith('risk_') || alertType.endsWith('_critical')) {
    return NotificationTypeFilter.health;
  }
  return NotificationTypeFilter.system;
}

/// Icon shown inside the leading colored square of a notification card.
IconData notificationLeadingIcon(String alertType) {
  final t = alertType.toLowerCase();
  if (t == 'sos' || t == 'manual') {
    return Icons.emergency_share_rounded;
  }
  if (t.startsWith('fall_')) {
    return Icons.warning_amber_rounded;
  }
  if (t.startsWith('medication_')) {
    return Icons.medication_rounded;
  }
  if (t.startsWith('risk_') || t.endsWith('_critical')) {
    return Icons.monitor_heart_rounded;
  }
  return Icons.notifications_active_rounded;
}

/// Solid background color for the leading icon square. Pairs with the
/// existing chip color helper but uses the saturated brand color so the
/// icon stands out against the card surface.
Color notificationLeadingIconBg(String alertType) {
  final t = alertType.toLowerCase();
  if (t == 'sos' ||
      t == 'manual' ||
      t.startsWith('fall_') ||
      t == 'risk_critical') {
    return AppColors.critical;
  }
  if (t.startsWith('risk_') || t.endsWith('_critical')) {
    return AppColors.warning;
  }
  if (t.startsWith('medication_')) {
    return AppColors.success;
  }
  return AppColors.info;
}

/// Coarse date buckets used to render section headers on the list. The
/// boundaries are local-time so a notification from "today" stays in
/// `today` regardless of UTC offsets.
enum NotificationDateBucket { today, yesterday, thisWeek, older }

NotificationDateBucket notificationDateBucketOf(DateTime createdAt) {
  final now = DateTime.now();
  final localCreated = createdAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final created = DateTime(
    localCreated.year,
    localCreated.month,
    localCreated.day,
  );
  final daysFromToday = today.difference(created).inDays;
  if (daysFromToday <= 0) return NotificationDateBucket.today;
  if (daysFromToday == 1) return NotificationDateBucket.yesterday;
  if (daysFromToday <= 6) return NotificationDateBucket.thisWeek;
  return NotificationDateBucket.older;
}

String notificationDateBucketLabel(NotificationDateBucket bucket) {
  switch (bucket) {
    case NotificationDateBucket.today:
      return 'Hôm nay';
    case NotificationDateBucket.yesterday:
      return 'Hôm qua';
    case NotificationDateBucket.thisWeek:
      return 'Tuần này';
    case NotificationDateBucket.older:
      return 'Trước đó';
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
