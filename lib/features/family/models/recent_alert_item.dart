/// Caregiver-feed alert types whitelisted by the backend.
///
/// Mirrors ``backend/app/core/alert_constants.py::CAREGIVER_FEED_ALERT_TYPES``.
/// Anything not in this enum is unknown to the mobile feed and renders as the
/// generic [RecentAlertType.unknown] bucket — never as a hard parse error,
/// because the backend may add new types ahead of a coordinated mobile
/// release.
enum RecentAlertType {
  sosTriggered,
  fallDetected,
  riskCritical,
  riskHigh,
  vitalAbnormal,
  sleepAnomaly,
  unknown;

  static RecentAlertType fromWire(String? raw) {
    switch (raw) {
      case 'sos_triggered':
        return RecentAlertType.sosTriggered;
      case 'fall_detected':
        return RecentAlertType.fallDetected;
      case 'risk_critical':
        return RecentAlertType.riskCritical;
      case 'risk_high':
        return RecentAlertType.riskHigh;
      case 'vital_abnormal':
        return RecentAlertType.vitalAbnormal;
      case 'sleep_anomaly':
        return RecentAlertType.sleepAnomaly;
      default:
        return RecentAlertType.unknown;
    }
  }
}

/// Severity bucket — keeps colour/icon mapping in the UI deterministic.
///
/// We accept 'normal' as an alias for 'low' because the backend Alert model
/// CHECK constraint for ``severity`` historically accepted both, and some
/// older simulator-authored rows still use it.
enum RecentAlertSeverity {
  low,
  medium,
  high,
  critical;

  static RecentAlertSeverity fromWire(String? raw) {
    switch (raw) {
      case 'critical':
        return RecentAlertSeverity.critical;
      case 'high':
        return RecentAlertSeverity.high;
      case 'medium':
        return RecentAlertSeverity.medium;
      case 'low':
      case 'normal':
      default:
        return RecentAlertSeverity.low;
    }
  }
}

/// Where tapping the alert card should land.
///
/// The backend never emits a route string — it emits the [type] of target
/// plus its primary key. The mobile router owns the final URL so backend
/// changes can't break navigation. Unknown targets are mapped to [unknown]
/// and the UI degrades gracefully (shows a bottom sheet instead of pushing).
enum RecentAlertDeepLinkType {
  sosEvent,
  riskScore,
  fallEvent,
  alert,
  unknown;

  static RecentAlertDeepLinkType fromWire(String? raw) {
    switch (raw) {
      case 'sos_event':
        return RecentAlertDeepLinkType.sosEvent;
      case 'risk_score':
        return RecentAlertDeepLinkType.riskScore;
      case 'fall_event':
        return RecentAlertDeepLinkType.fallEvent;
      case 'alert':
        return RecentAlertDeepLinkType.alert;
      default:
        return RecentAlertDeepLinkType.unknown;
    }
  }
}

class RecentAlertDeepLink {
  const RecentAlertDeepLink({required this.type, required this.id});

  final RecentAlertDeepLinkType type;
  final int id;

  factory RecentAlertDeepLink.fromJson(Map<String, dynamic> json) {
    return RecentAlertDeepLink(
      type: RecentAlertDeepLinkType.fromWire(json['type'] as String?),
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One row on the "Cảnh báo gần đây" feed.
///
/// Field semantics:
///   * [id] / [uuid] — primary key + cross-system id; UI uses [uuid] as the
///     ListView key so re-orderings don't cause widget rebuilds.
///   * [alertType] — strongly typed for icon/colour mapping. The original
///     wire string is preserved in [rawAlertType] for analytics & debugging.
///   * [severity] — strongly typed for colour mapping; also see
///     [rawSeverity].
///   * [title] / [message] — already-localised strings from the backend
///     (Vietnamese). The mobile layer never re-translates.
///   * [occurredAt] — UTC; the UI converts to local for display.
///   * [isResolved] — drives the "Đã xử lý" chip + opacity.
///   * [deepLink] — optional navigation hint.
class RecentAlertItem {
  const RecentAlertItem({
    required this.id,
    required this.uuid,
    required this.alertType,
    required this.rawAlertType,
    required this.severity,
    required this.rawSeverity,
    required this.title,
    required this.occurredAt,
    this.message,
    this.isResolved = false,
    this.deepLink,
  });

  final int id;
  final String uuid;
  final RecentAlertType alertType;
  final String rawAlertType;
  final RecentAlertSeverity severity;
  final String rawSeverity;
  final String title;
  final String? message;
  final DateTime occurredAt;
  final bool isResolved;
  final RecentAlertDeepLink? deepLink;

  factory RecentAlertItem.fromJson(Map<String, dynamic> json) {
    final rawType = (json['alert_type'] as String?) ?? '';
    final rawSev = (json['severity'] as String?) ?? '';
    final rawOccurred = json['occurred_at'] as String?;

    return RecentAlertItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] as String?) ?? '',
      alertType: RecentAlertType.fromWire(rawType),
      rawAlertType: rawType,
      severity: RecentAlertSeverity.fromWire(rawSev),
      rawSeverity: rawSev,
      title: (json['title'] as String?) ?? '',
      message: json['message'] as String?,
      // Backend always sends ISO-8601 with offset; ``DateTime.parse``
      // tolerates 'Z'/'+07:00' alike. Falls back to ``now`` defensively so a
      // malformed payload never crashes the list.
      occurredAt: rawOccurred != null
          ? (DateTime.tryParse(rawOccurred) ?? DateTime.now()).toUtc()
          : DateTime.now().toUtc(),
      isResolved: json['is_resolved'] as bool? ?? false,
      deepLink: json['deep_link'] is Map
          ? RecentAlertDeepLink.fromJson(
              Map<String, dynamic>.from(json['deep_link'] as Map),
            )
          : null,
    );
  }
}

/// Wire response for ``GET /caregiver/patients/{id}/recent-alerts``.
class RecentAlertsResponse {
  const RecentAlertsResponse({
    required this.items,
    required this.windowDays,
    required this.totalInWindow,
  });

  final List<RecentAlertItem> items;
  final int windowDays;
  final int totalInWindow;

  factory RecentAlertsResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<RecentAlertItem> parsed = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((m) => RecentAlertItem.fromJson(
                    Map<String, dynamic>.from(m),
                  ))
              .toList(growable: false)
        : const <RecentAlertItem>[];

    return RecentAlertsResponse(
      items: parsed,
      windowDays: (json['window_days'] as num?)?.toInt() ?? 7,
      totalInWindow: (json['total_in_window'] as num?)?.toInt() ?? parsed.length,
    );
  }
}
