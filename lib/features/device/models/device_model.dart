class DeviceModel {
  final int id;
  final String uuid;
  final String? deviceName;
  final String deviceType;
  final String? model;
  final String? firmwareVersion;
  final String? macAddress;
  final String? serialNumber;
  final bool isActive;
  final bool isOnline;
  final int? batteryLevel;
  final int? signalStrength;
  final DateTime? lastSeenAt;
  final DateTime? lastSyncAt;
  final String? mqttClientId;
  final DateTime? registeredAt;

  /// Persisted notification + calibration preferences as returned by
  /// `DeviceItemResponse.calibration_data`. The configure screen seeds its
  /// notify_high_hr / notify_low_spo2 / notify_high_bp toggles from this
  /// map so they reflect the saved values instead of always defaulting to
  /// `true`. Null when the device has never had settings saved.
  final Map<String, dynamic>? calibrationData;

  DeviceModel({
    required this.id,
    required this.uuid,
    this.deviceName,
    required this.deviceType,
    this.model,
    this.firmwareVersion,
    this.macAddress,
    this.serialNumber,
    required this.isActive,
    required this.isOnline,
    this.batteryLevel,
    this.signalStrength,
    this.lastSeenAt,
    this.lastSyncAt,
    this.mqttClientId,
    this.registeredAt,
    this.calibrationData,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      deviceName: json['device_name'] as String?,
      deviceType: json['device_type'] as String? ?? 'unknown',
      model: json['model'] as String?,
      firmwareVersion: json['firmware_version'] as String?,
      macAddress: json['mac_address'] as String?,
      serialNumber: json['serial_number'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      batteryLevel: (json['battery_level'] as num?)?.toInt(),
      signalStrength: (json['signal_strength'] as num?)?.toInt(),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String).toLocal()
          : null,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'] as String).toLocal()
          : null,
      mqttClientId: json['mqtt_client_id'] as String?,
      registeredAt: json['registered_at'] != null
          ? DateTime.parse(json['registered_at'] as String).toLocal()
          : null,
      calibrationData: json['calibration_data'] is Map
          ? Map<String, dynamic>.from(json['calibration_data'] as Map)
          : null,
    );
  }

  String get displayName => deviceName?.trim().isNotEmpty == true
      ? deviceName!.trim()
      : 'Thiet bi #$id';

  String get typeLabel {
    switch (deviceType) {
      case 'smartwatch':
        return 'Dong ho thong minh';
      case 'fitness_band':
        return 'Vong deo suc khoe';
      case 'medical_device':
        return 'Thiet bi y te';
      default:
        return deviceType;
    }
  }
}
