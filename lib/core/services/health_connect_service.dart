// lib/core/services/health_connect_service.dart
//
// Phase 2 of the Redmi Watch 3 (M2216W1) integration.
//
// Pre-Phase-2 the app could not read any real vital signs. The Phase 1
// BLE scan recorded a watch's MAC + GATT metadata but never carried
// HR/SpO2/Steps/Sleep because Redmi/Xiaomi watches only exchange that
// data through Mi Fitness's proprietary Xiaomi-cloud handshake.
//
// Health Connect is the OS-level escape hatch: Mi Fitness writes the
// readings into Android Health Connect, and any app the user has
// authorised can read them back through a stable, vendor-neutral API.
// This service is the boundary between the Flutter widget tree and the
// `health` package (which itself wraps `androidx.health.connect.client`).
//
// Responsibilities:
//   * Detect Health Connect availability (installed / needs update / not
//     supported on this Android version) so the onboarding screen can
//     deep-link to Play Store instead of crashing.
//   * Request the read-only set of permissions we declared in the
//     AndroidManifest. Permissions are batch-granted via the dedicated
//     Health Connect UI; we do not call permission_handler here.
//   * Fetch HR / SpO2 / Steps / Sleep / Body Temperature / Respiratory
//     Rate / Blood Pressure samples since a caller-supplied timestamp,
//     normalised into a single Dart record so the repository layer can
//     map them straight to the backend's `MobileVitalSample` schema.
//   * Surface the raw source-app attribution (e.g. "Mi Fitness") so the
//     UI can label data source honestly and the backend can keep audit
//     trails.

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Availability state of Health Connect on this device. Drives the
/// onboarding CTA copy: install / update / cấp quyền.
enum HealthConnectAvailability {
  available,
  needsUpdate,
  notInstalled,
  notSupported,
}

/// Permission request outcome surfaced to the UI. The Health Connect
/// permission sheet is partial-grant friendly so we distinguish "fully
/// granted" from "some permissions denied".
enum HealthPermissionState {
  granted,
  partiallyGranted,
  denied,
  unknown,
}

/// Single normalised reading. Use a record-style class instead of the
/// plugin's [HealthDataPoint] so the repository / provider layer never
/// imports `health` directly.
@immutable
class HealthVitalReading {
  final HealthDataType type;
  final DateTime startTime;
  final DateTime endTime;
  final double value;
  final String unit;
  final String sourceName;

  const HealthVitalReading({
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.value,
    required this.unit,
    required this.sourceName,
  });

  /// True when the reading came from Mi Fitness (case-insensitive). Any
  /// other source (Samsung Health, Google Fit, Garmin Connect...) is
  /// also accepted but tagged differently in the UI so QA can spot
  /// cross-vendor mixing during demos.
  bool get isMiFitness => sourceName.toLowerCase().contains('mi fitness') ||
      sourceName.toLowerCase().contains('xiaomi');
}

/// Vital data types we ask Health Connect for. Anchored here so the
/// onboarding / settings screens can render the same list in the
/// permissions explainer without duplicating it.
const List<HealthDataType> kHealthConnectTypes = [
  HealthDataType.HEART_RATE,
  HealthDataType.STEPS,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.BODY_TEMPERATURE,
  HealthDataType.RESPIRATORY_RATE,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
];

/// Singleton facade. Stateless across hot-reloads; the underlying
/// `Health()` instance is cached so repeated `configure()` calls are a
/// no-op.
class HealthConnectService {
  HealthConnectService._() : _health = Health();
  static final HealthConnectService instance = HealthConnectService._();

  final Health _health;
  bool _configured = false;

  /// Lazy initialise the plugin. Calling more than once is safe — the
  /// plugin's own configure() is idempotent.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Lightweight check used by the onboarding screen to pick the right
  /// CTA. Does not show any UI.
  Future<HealthConnectAvailability> checkAvailability() async {
    await _ensureConfigured();
    try {
      final sdk = await _health.getHealthConnectSdkStatus();
      switch (sdk) {
        case HealthConnectSdkStatus.sdkAvailable:
          return HealthConnectAvailability.available;
        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          return HealthConnectAvailability.needsUpdate;
        case HealthConnectSdkStatus.sdkUnavailable:
          return HealthConnectAvailability.notInstalled;
        default:
          return HealthConnectAvailability.notSupported;
      }
    } catch (e, st) {
      debugPrint('HealthConnect availability check failed: $e\n$st');
      return HealthConnectAvailability.notSupported;
    }
  }

  /// Read-only permission check. Triggers no UI — used to gate the
  /// "Đồng bộ ngay" button.
  Future<HealthPermissionState> hasPermissions() async {
    await _ensureConfigured();
    final granted = await _health.hasPermissions(
      kHealthConnectTypes,
      permissions: List.filled(
        kHealthConnectTypes.length,
        HealthDataAccess.READ,
      ),
    );
    if (granted == null) return HealthPermissionState.unknown;
    return granted
        ? HealthPermissionState.granted
        : HealthPermissionState.denied;
  }

  /// Pop the Health Connect permission sheet. Returns the consolidated
  /// state after the user dismisses it. The sheet itself supports
  /// per-type partial grants; we treat any missing type as
  /// `partiallyGranted`.
  Future<HealthPermissionState> requestPermissions() async {
    await _ensureConfigured();
    final granted = await _health.requestAuthorization(
      kHealthConnectTypes,
      permissions: List.filled(
        kHealthConnectTypes.length,
        HealthDataAccess.READ,
      ),
    );
    if (!granted) return HealthPermissionState.denied;

    // Re-check per-type to surface partial grants — Health Connect lets
    // the user uncheck individual data types in the permission sheet.
    final typed = await _health.hasPermissions(
      kHealthConnectTypes,
      permissions: List.filled(
        kHealthConnectTypes.length,
        HealthDataAccess.READ,
      ),
    );
    if (typed == true) return HealthPermissionState.granted;
    if (typed == null) return HealthPermissionState.unknown;
    return HealthPermissionState.partiallyGranted;
  }

  /// Fetch every data point of [types] inserted since [since]. We let the
  /// caller pass [now] explicitly so unit tests can pin the upper bound;
  /// production code uses `DateTime.now()` by default. The plugin returns
  /// the intersection of all requested types in a single list — sort by
  /// `dateFrom` ascending to keep the backend ingest deterministic.
  Future<List<HealthVitalReading>> readSince({
    required DateTime since,
    DateTime? now,
    List<HealthDataType> types = kHealthConnectTypes,
  }) async {
    await _ensureConfigured();
    final endTime = now ?? DateTime.now();
    if (!since.isBefore(endTime)) return const [];

    final raw = await _health.getHealthDataFromTypes(
      types: types,
      startTime: since,
      endTime: endTime,
    );
    final deduped = Health().removeDuplicates(raw);
    deduped.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

    return deduped.map(_mapPoint).whereType<HealthVitalReading>().toList();
  }

  /// Best-effort mapper from the plugin's loose [HealthDataPoint] into
  /// our typed value object. Drops any point we cannot interpret as a
  /// numeric value (the backend ingest schema rejects null clinical
  /// signals anyway, so the early drop spares a round trip).
  HealthVitalReading? _mapPoint(HealthDataPoint p) {
    final value = p.value;
    if (value is! NumericHealthValue) {
      // Composite values (e.g. blood pressure) come back through their
      // own SYSTOLIC/DIASTOLIC channels, so we can safely skip non-numeric
      // payloads here.
      return null;
    }
    final numeric = value.numericValue.toDouble();

    return HealthVitalReading(
      type: p.type,
      startTime: p.dateFrom,
      endTime: p.dateTo,
      value: numeric,
      unit: p.unit.name,
      sourceName: p.sourceName,
    );
  }
}
