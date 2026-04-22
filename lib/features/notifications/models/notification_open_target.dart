import 'package:flutter/foundation.dart';

@immutable
class NotificationOpenTarget {
  const NotificationOpenTarget({
    required this.type,
    this.sosId,
    this.notificationId,
    this.alertType,
    this.riskLevel,
    this.riskScoreId,
    this.title,
    this.message,
  });

  final String type;
  final String? sosId;
  final String? notificationId;
  final String? alertType;
  final String? riskLevel;
  final int? riskScoreId;
  final String? title;
  final String? message;
}
