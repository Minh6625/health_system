/// SOS Event model representing an emergency alert
class SOSEventModel {
  final String id;
  final PatientInfoModel patient;
  final String triggerType; // 'fall_detected' | 'manual' | 'vital_critical'
  final DateTime triggerTime;
  final String status; // 'active' | 'resolved'
  final LocationInfoModel location;
  final FallDetectionXAIModel? fallDetectionXAI;
  final ResolutionInfoModel? resolution;

  SOSEventModel({
    required this.id,
    required this.patient,
    required this.triggerType,
    required this.triggerTime,
    required this.status,
    required this.location,
    this.fallDetectionXAI,
    this.resolution,
  });

  bool get isActive => status == 'active';
  bool get isFallDetection => triggerType == 'fall_detected';

  /// Calculate elapsed time since trigger
  Duration get elapsedTime => DateTime.now().difference(triggerTime);

  factory SOSEventModel.fromJson(Map<String, dynamic> json) {
    return SOSEventModel(
      id: json['sos_id'].toString(), // Backend returns int, convert to String
      patient: PatientInfoModel.fromJson(
        json['patient'] as Map<String, dynamic>,
      ),
      triggerType: json['trigger_type'] as String,
      // Bug fix G-7: backend serialises ``trigger_time`` in UTC (ISO 8601 with
      // ``Z`` or ``+00:00``). ``DateTime.parse`` preserves that timezone, and
      // ``DateFormat.format`` then prints in whatever timezone the DateTime
      // is in — which produced UTC strings on a VN device. ``.toLocal()``
      // shifts the value to the device's local zone (UTC+7 for VN) so the
      // SOS detail card shows ``HH:mm:ss`` matching the user's clock.
      triggerTime: DateTime.parse(json['trigger_time'] as String).toLocal(),
      status: json['status'] as String,
      location: json['location'] != null
          ? LocationInfoModel.fromJson(json['location'] as Map<String, dynamic>)
          : LocationInfoModel(
              latitude: null,
              longitude: null,
              accuracy: null,
              address: null,
              lastUpdated: DateTime.now(),
            ),
      fallDetectionXAI: json['fall_detection_xai'] != null
          ? FallDetectionXAIModel.fromJson(
              json['fall_detection_xai'] as Map<String, dynamic>,
            )
          : null,
      resolution: json['resolution'] != null
          ? ResolutionInfoModel.fromJson(
              json['resolution'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient': patient.toJson(),
      'trigger_type': triggerType,
      'trigger_time': triggerTime.toIso8601String(),
      'status': status,
      'location': location.toJson(),
      'fall_detection_xai': fallDetectionXAI?.toJson(),
      'resolution': resolution?.toJson(),
    };
  }
}

/// Patient information in SOS event
class PatientInfoModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String phone;

  PatientInfoModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.phone,
  });

  factory PatientInfoModel.fromJson(Map<String, dynamic> json) {
    return PatientInfoModel(
      id: json['user_id'].toString(), // Backend returns int, convert to String
      name: json['full_name'] as String,
      photoUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'photo_url': photoUrl, 'phone': phone};
  }
}

/// Location information with GPS coordinates
class LocationInfoModel {
  final double? latitude;
  final double? longitude;
  final double? accuracy; // in meters
  final String? address;
  final DateTime lastUpdated;

  LocationInfoModel({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.address,
    required this.lastUpdated,
  });

  /// Get Google Maps URL for this location
  String get googleMapsUrl {
    if (latitude != null && longitude != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    }
    return '';
  }

  /// Check if location is stale (> 5 minutes old)
  bool get isStale => DateTime.now().difference(lastUpdated).inMinutes > 5;

  /// Get accuracy quality: 'good' | 'fair' | 'poor'
  String get accuracyQuality {
    if (accuracy == null) return 'unknown';
    if (accuracy! < 20) return 'good';
    if (accuracy! < 50) return 'fair';
    return 'poor';
  }

  factory LocationInfoModel.fromJson(Map<String, dynamic> json) {
    return LocationInfoModel(
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
      address: json['address'] as String?,
      // Bug fix G-7: see ``SOSEventModel.fromJson`` for the rationale —
      // ``last_updated`` is also UTC on the wire and must be converted to
      // local time before downstream ``DateFormat`` calls.
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// XAI explanation for fall detection
class FallDetectionXAIModel {
  /// Detector confidence in the canonical 0.0-1.0 range used by the backend
  /// (`fall_event.confidence` and `risk_score`). Multiply by 100 for display.
  final double confidence;
  final List<TimelineEventModel> timeline;

  /// Human-readable explanation emitted by the backend
  /// (`backend/app/schemas/emergency.py` -> `FallDetectionXAI.trigger_reason`).
  /// Optional so older payloads / unit tests stay valid.
  final String? triggerReason;

  FallDetectionXAIModel({
    required this.confidence,
    required this.timeline,
    this.triggerReason,
  });

  factory FallDetectionXAIModel.fromJson(Map<String, dynamic> json) {
    return FallDetectionXAIModel(
      confidence: (json['confidence'] as num).toDouble(),
      timeline: (json['timeline'] as List)
          .map((e) => TimelineEventModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      triggerReason: json['trigger_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'confidence': confidence,
      'timeline': timeline.map((e) => e.toJson()).toList(),
      'trigger_reason': triggerReason,
    };
  }
}

/// Timeline event in XAI explanation
class TimelineEventModel {
  final String time;
  final String description;

  TimelineEventModel({required this.time, required this.description});

  factory TimelineEventModel.fromJson(Map<String, dynamic> json) {
    // Backend `TimelineEvent` schema (backend/app/schemas/emergency.py) emits
    // `time_offset` and `event`. The previous keys (`time`, `description`) did
    // not exist in the payload, so casting null → String crashed
    // EmergencySOSDetailScreen whenever an active fall-detection SOS rendered
    // its XAI timeline. Read the canonical backend keys; tolerate the legacy
    // names as a fallback in case the payload comes from an older mock.
    return TimelineEventModel(
      time:
          (json['time_offset'] as String?) ?? (json['time'] as String? ?? ''),
      description:
          (json['event'] as String?) ??
          (json['description'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {'time_offset': time, 'event': description};
  }
}

/// Resolution information when SOS is resolved
class ResolutionInfoModel {
  final String resolutionStatus;
  final String resolvedBy; // Name of person who resolved
  final DateTime resolvedTime;
  final String? notes;

  ResolutionInfoModel({
    required this.resolutionStatus,
    required this.resolvedBy,
    required this.resolvedTime,
    this.notes,
  });

  factory ResolutionInfoModel.fromJson(Map<String, dynamic> json) {
    return ResolutionInfoModel(
      resolutionStatus: json['resolution_status'] as String? ?? 'safe',
      resolvedBy: json['resolved_by_name'] as String,
      // Bug fix G-7: see ``SOSEventModel.fromJson`` for the rationale —
      // ``resolved_at`` arrives in UTC and must be normalised to the device's
      // local zone for the resolution-info card.
      resolvedTime: DateTime.parse(json['resolved_at'] as String).toLocal(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resolution_status': resolutionStatus,
      'resolved_by': resolvedBy,
      'resolved_time': resolvedTime.toIso8601String(),
      'notes': notes,
    };
  }
}
