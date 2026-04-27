/// Mobile-side model for the backend's `FallEventResponse`.
///
/// Phase 4B-full slice 2c (mobile half). Mirrors
/// ``backend/app/schemas/fall_telemetry.py::FallEventResponse`` —
/// every field on the server-side DTO has a matching field here, with
/// JSON parsing tolerant of nullables + Decimal-as-num coercion.
///
/// The server pre-computes ``status``; we surface it as a typed enum
/// (`FallEventStatus`) so the UI can switch on it without re-parsing
/// strings.
library;

/// State machine projection the backend derives from the workflow
/// columns; mirrors `app/services/fall_event_service.py::derive_status`.
enum FallEventStatus {
  /// Fall detected, no user action yet, no auto-SOS.
  detected,

  /// User explicitly cleared the alert ("Tôi ổn").
  dismissed,

  /// User responded but did not cancel — they need help, the SOS
  /// workflow is engaged.
  confirmed,

  /// Auto-SOS escalation already fired (user did NOT respond inside
  /// the configured window).
  escalated,

  /// Defensive default for any string the backend adds in a future
  /// version that this binary doesn't recognise. UI should treat this
  /// the same as ``detected`` (most conservative — show the alert).
  unknown;

  /// Parse the server's `status` string. Unknown values land in
  /// :data:`unknown` rather than throwing — the mobile parser is
  /// forward-compatible with future status additions.
  static FallEventStatus fromJson(String? raw) {
    switch (raw) {
      case 'detected':
        return FallEventStatus.detected;
      case 'dismissed':
        return FallEventStatus.dismissed;
      case 'confirmed':
        return FallEventStatus.confirmed;
      case 'escalated':
        return FallEventStatus.escalated;
      default:
        return FallEventStatus.unknown;
    }
  }

  /// True when this status indicates the alert flow is still active
  /// and should be shown front-and-centre. Used by the home screen
  /// banner + the alert-screen auto-dismiss check.
  bool get isActive =>
      this == FallEventStatus.detected || this == FallEventStatus.unknown;

  /// True when the SOS workflow already engaged (user confirmed OR
  /// auto-SOS fired). The fall_alert_screen does NOT show a dismiss
  /// button in this state — the SOS screen takes over.
  bool get hasEscalated =>
      this == FallEventStatus.confirmed ||
      this == FallEventStatus.escalated;
}

/// One fall event as the mobile UI sees it.
class FallEvent {
  /// Database primary key.
  final int id;

  /// Stable UUID — used as the dedup key for FCM-pushed events so a
  /// retry doesn't double-render the alert overlay.
  final String uuid;

  /// `devices.id` that produced the event.
  final int deviceId;

  /// When the model-api flagged the IMU window as a fall.
  final DateTime detectedAt;

  /// Model confidence (0..1).
  final double confidence;

  /// Model bundle version (e.g. ``"v1.0"``). Optional — older rows
  /// may have NULL.
  final String? modelVersion;

  /// GPS coords at detection time (optional).
  final double? latitude;
  final double? longitude;
  final String? address;

  /// Workflow timestamps + flags.
  final DateTime? userNotifiedAt;
  final DateTime? userRespondedAt;
  final bool userCancelled;
  final String? cancelReason;
  final bool sosTriggered;

  /// Server-derived state machine projection.
  final FallEventStatus status;

  /// Free-form explainability bundle (`meta`, `shap`, etc.). The
  /// patient surface ignores this; the future clinician audience will
  /// surface it on a dedicated SHAP screen.
  final Map<String, dynamic>? features;

  const FallEvent({
    required this.id,
    required this.uuid,
    required this.deviceId,
    required this.detectedAt,
    required this.confidence,
    required this.status,
    this.modelVersion,
    this.latitude,
    this.longitude,
    this.address,
    this.userNotifiedAt,
    this.userRespondedAt,
    this.userCancelled = false,
    this.cancelReason,
    this.sosTriggered = false,
    this.features,
  });

  factory FallEvent.fromJson(Map<String, dynamic> json) {
    return FallEvent(
      id: (json['id'] as num).toInt(),
      uuid: json['uuid'] as String? ?? '',
      deviceId: (json['device_id'] as num).toInt(),
      detectedAt: DateTime.parse(json['detected_at'] as String).toLocal(),
      confidence: (json['confidence'] as num).toDouble(),
      modelVersion: json['model_version'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      userNotifiedAt: _parseOptionalDate(json['user_notified_at']),
      userRespondedAt: _parseOptionalDate(json['user_responded_at']),
      userCancelled: json['user_cancelled'] as bool? ?? false,
      cancelReason: json['cancel_reason'] as String?,
      sosTriggered: json['sos_triggered'] as bool? ?? false,
      status: FallEventStatus.fromJson(json['status'] as String?),
      features: json['features'] is Map<String, dynamic>
          ? json['features'] as Map<String, dynamic>
          : null,
    );
  }

  /// Build a copy with a subset of fields replaced. Used after dismiss
  /// when the provider wants to reflect the new status without
  /// re-fetching.
  FallEvent copyWith({
    DateTime? userRespondedAt,
    bool? userCancelled,
    String? cancelReason,
    FallEventStatus? status,
  }) {
    return FallEvent(
      id: id,
      uuid: uuid,
      deviceId: deviceId,
      detectedAt: detectedAt,
      confidence: confidence,
      modelVersion: modelVersion,
      latitude: latitude,
      longitude: longitude,
      address: address,
      userNotifiedAt: userNotifiedAt,
      userRespondedAt: userRespondedAt ?? this.userRespondedAt,
      userCancelled: userCancelled ?? this.userCancelled,
      cancelReason: cancelReason ?? this.cancelReason,
      sosTriggered: sosTriggered,
      status: status ?? this.status,
      features: features,
    );
  }

  static DateTime? _parseOptionalDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.parse(raw).toLocal();
    }
    return null;
  }
}

/// Paginated wrapper mirroring ``FallEventListResponse`` on the
/// backend.
class FallEventList {
  final List<FallEvent> items;
  final int total;
  final int limit;
  final int offset;

  const FallEventList({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory FallEventList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <FallEvent>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(FallEvent.fromJson(raw));
        }
      }
    }
    return FallEventList(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      limit: (json['limit'] as num?)?.toInt() ?? items.length,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => items.isEmpty;
  int get length => items.length;
}
