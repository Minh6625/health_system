class NotificationEvent {
  NotificationEvent({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required Map<String, dynamic> data,
  }) : data = Map<String, dynamic>.unmodifiable(
         data.map(
           (String key, dynamic value) => MapEntry(
             key,
             value is Map
                 ? Map<String, dynamic>.unmodifiable(
                     value.map(
                       (dynamic nestedKey, dynamic nestedValue) =>
                           MapEntry(nestedKey.toString(), nestedValue),
                     ),
                   )
                 : value,
           ),
         ),
       );

  final String id;
  final String alertType;
  final String severity;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> data;

  Map<String, dynamic> toItemMap() {
    return <String, dynamic>{
      'id': id,
      'alert_type': alertType,
      'severity': severity,
      'title': title,
      'message': message,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_read': isRead,
      'data': Map<String, dynamic>.from(data),
    };
  }
}
