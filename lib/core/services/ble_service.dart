// lib/core/services/ble_service.dart
//
// Phase 1 of the Redmi Watch 3 (M2216W1) integration.
//
// Responsibilities:
//   * Verify the platform Bluetooth adapter is on and the runtime permissions
//     required for BLE scan/connect on Android 12+ are granted.
//   * Stream nearby BLE advertisements filtered by name prefix (Xiaomi /
//     Redmi / Mi watches and bands) so the connect screen lists only
//     relevant devices instead of every BLE peripheral in range.
//   * Connect to a chosen advertisement, run GATT discovery, and best-effort
//     read the few standard characteristics that Redmi watches *might*
//     expose (Battery 0x180F, Device Information 0x180A). The Xiaomi
//     proprietary protocol is intentionally NOT spoken here — see
//     `plans/redmi_watch_3_ble_plan_*.md` for why this is scoped to
//     "connection-only" for the academic deadline.
//
// Errors are surfaced as [BleFailure] with discriminated reason codes so
// the UI layer can render contextual CTAs (turn on Bluetooth, open
// settings, etc.) without parsing raw plugin exceptions.

import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reason codes for [BleFailure]. Each maps to a concrete UI message in
/// `device_qr_scan_step.dart` so the user gets actionable copy instead of
/// a stack trace.
enum BleFailureReason {
  unsupported, // Platform has no BLE radio (e.g. emulator).
  adapterOff, // Adapter is present but powered off.
  permissionDenied, // User denied SCAN/CONNECT (recoverable).
  permissionPermanentlyDenied, // User checked "Don't ask again".
  locationServicesOff, // Required on Android <= 11 for BLE scan.
  scanTimeout, // Scan window expired with zero hits.
  connectFailed, // GATT connect raised at the platform layer.
  unknown,
}

/// Outcome envelope returned by every public [BleService] entrypoint that
/// can fail at the platform layer. Using a sealed-style result keeps the
/// caller honest about handling each branch instead of swallowing
/// exceptions in a generic try/catch.
class BleFailure implements Exception {
  final BleFailureReason reason;
  final String message;
  final Object? cause;

  const BleFailure(this.reason, this.message, {this.cause});

  @override
  String toString() => 'BleFailure($reason): $message';
}

/// Lightweight value object describing a single BLE advertisement seen by
/// the scanner. Decoupled from the plugin's [ScanResult] so the UI and
/// providers do not import `flutter_blue_plus` directly.
class BleScanEntry {
  final String remoteId; // Stable per-session id (MAC on Android, UUID on iOS).
  final String name; // Best-known advertised name; never empty for filtered hits.
  final int rssi;
  final DateTime seenAt;

  const BleScanEntry({
    required this.remoteId,
    required this.name,
    required this.rssi,
    required this.seenAt,
  });

  /// Returns the canonical MAC string `AA:BB:CC:DD:EE:FF` when the platform
  /// surfaces one (Android), otherwise null. The backend pairing endpoint
  /// expects this exact format and rejects anything else with HTTP 422,
  /// so we normalise here rather than at the call site.
  String? get macAddress {
    final upper = remoteId.toUpperCase();
    final macPattern = RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$');
    return macPattern.hasMatch(upper) ? upper : null;
  }
}

/// Snapshot of a connected device after GATT discovery completes. Fields
/// are nullable because Redmi watches frequently *do not* expose the
/// standard Battery / Device Information services — pairing must still
/// succeed in that case so the UI shows "—" instead of erroring out.
class BleConnectedDevice {
  final String remoteId;
  final String name;
  final int? batteryLevel;
  final String? firmwareRevision;
  final String? manufacturer;
  final String? modelNumber;

  const BleConnectedDevice({
    required this.remoteId,
    required this.name,
    this.batteryLevel,
    this.firmwareRevision,
    this.manufacturer,
    this.modelNumber,
  });
}

/// Default name prefixes used to filter the scan stream. Matched
/// case-insensitively against [BluetoothDevice.platformName] so we surface
/// Xiaomi / Redmi / Mi wearables and skip the noise from earbuds, headsets
/// and unrelated peripherals. The connect screen can override this when
/// the user explicitly wants to broaden the search.
const Set<String> kDefaultRedmiNamePrefixes = {
  'redmi watch',
  'redmi smart band',
  'mi watch',
  'mi smart band',
  'mi band',
  'xiaomi watch',
  'xiaomi smart band',
};

/// Singleton BLE facade. Keeping this stateless across calls (apart from
/// the cached [FlutterBluePlus] subscriptions) means we never accidentally
/// hold a live connection across hot-reload boundaries — the plugin
/// disconnects automatically when the host activity dies.
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  /// Live adapter state for UI badges. Re-emits whenever the OS toggles
  /// Bluetooth so the connect screen can refresh its CTA without polling.
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Verifies the device can actually scan: BLE radio supported, adapter on,
  /// runtime permissions granted. Returns normally on success and throws a
  /// typed [BleFailure] on every failure so callers can switch on
  /// [BleFailureReason] for messaging.
  Future<void> ensureReady() async {
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      throw const BleFailure(
        BleFailureReason.unsupported,
        'Thiết bị không hỗ trợ Bluetooth Low Energy.',
      );
    }

    if (Platform.isAndroid) {
      await _ensureAndroidPermissions();
    }

    final state = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 3),
            onTimeout: () => BluetoothAdapterState.off);
    if (state != BluetoothAdapterState.on) {
      throw const BleFailure(
        BleFailureReason.adapterOff,
        'Vui lòng bật Bluetooth để quét đồng hồ.',
      );
    }
  }

  Future<void> _ensureAndroidPermissions() async {
    // Android 12+ uses the new neverForLocation BLE permission set.
    // permission_handler maps both buckets transparently — calling
    // `request()` on a permission the SDK does not need is a no-op, so we
    // request the union and let the platform decide.
    final required = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    final statuses = await required.request();
    final denied = statuses.entries.where((e) => e.value.isDenied).toList();
    final permanent = statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .toList();

    if (permanent.isNotEmpty) {
      throw BleFailure(
        BleFailureReason.permissionPermanentlyDenied,
        'Bạn đã từ chối quyền Bluetooth/Vị trí. Mở cài đặt ứng dụng để cấp lại.',
        cause: permanent.map((e) => e.key.toString()).toList(),
      );
    }
    if (denied.isNotEmpty) {
      throw BleFailure(
        BleFailureReason.permissionDenied,
        'Cần quyền Bluetooth để quét thiết bị quanh đây.',
        cause: denied.map((e) => e.key.toString()).toList(),
      );
    }
  }

  /// Streams [BleScanEntry] hits filtered by [namePrefixes]. The scan is
  /// stopped automatically when [timeout] elapses or the returned stream
  /// is cancelled by the caller, whichever comes first. We deliberately
  /// surface every advertisement (no de-duplication) so the UI layer can
  /// implement its own freshness/RSSI policy.
  Stream<BleScanEntry> startScan({
    Duration timeout = const Duration(seconds: 30),
    Set<String> namePrefixes = kDefaultRedmiNamePrefixes,
  }) {
    final controller = StreamController<BleScanEntry>();
    StreamSubscription<List<ScanResult>>? sub;

    Future<void> close() async {
      try {
        if (FlutterBluePlus.isScanningNow) {
          await FlutterBluePlus.stopScan();
        }
      } catch (_) {
        // Best-effort: ignore stop errors on disposal.
      }
      await sub?.cancel();
      if (!controller.isClosed) await controller.close();
    }

    Future<void> begin() async {
      try {
        // Caller is expected to have invoked ensureReady(); we still
        // re-check the adapter so a flipped switch mid-flow surfaces a
        // clean failure instead of an opaque platform exception.
        final state = await FlutterBluePlus.adapterState.first;
        if (state != BluetoothAdapterState.on) {
          controller.addError(const BleFailure(
            BleFailureReason.adapterOff,
            'Bluetooth đã tắt trước khi bắt đầu quét.',
          ));
          await close();
          return;
        }

        sub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final name = r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : r.device.platformName;
            if (name.isEmpty) continue;
            final lower = name.toLowerCase();
            final match =
                namePrefixes.any((prefix) => lower.startsWith(prefix));
            if (!match) continue;
            controller.add(BleScanEntry(
              remoteId: r.device.remoteId.str,
              name: name,
              rssi: r.rssi,
              seenAt: DateTime.now(),
            ));
          }
        }, onError: (error, stack) {
          controller.addError(BleFailure(
            BleFailureReason.unknown,
            'Lỗi khi đọc kết quả quét BLE.',
            cause: error,
          ));
        });

        await FlutterBluePlus.startScan(timeout: timeout);

        // When the plugin's internal timeout fires it stops scanning but
        // does not close our controller — schedule the cleanup ourselves
        // so the consumer's `await for` exits cleanly.
        Future.delayed(timeout, close);
      } on FlutterBluePlusException catch (e) {
        controller.addError(BleFailure(
          BleFailureReason.unknown,
          'Không thể bắt đầu quét BLE: ${e.description ?? e.toString()}',
          cause: e,
        ));
        await close();
      } catch (e) {
        controller.addError(BleFailure(
          BleFailureReason.unknown,
          'Không thể bắt đầu quét BLE.',
          cause: e,
        ));
        await close();
      }
    }

    controller.onListen = begin;
    controller.onCancel = close;
    return controller.stream;
  }

  /// Stops an in-flight scan. Idempotent — safe to call when no scan is
  /// currently active.
  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  /// Best-effort metadata fetch without OS-level bonding.
  ///
  /// Connects briefly, runs GATT discovery, reads the Device Information
  /// service (0x180A) and the Battery Service (0x180F) when present, then
  /// disconnects. We deliberately avoid `createBond()` because the Redmi
  /// Watch 3 only exchanges meaningful data with Mi Fitness — forcing a
  /// bond would either fail silently or leave a dead pairing in the OS
  /// settings. Returning a partially-populated [BleConnectedDevice] is
  /// fine: every field is nullable and the caller surfaces "—" for the
  /// missing ones.
  Future<BleConnectedDevice> peekMetadata(
    String remoteId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final device = BluetoothDevice.fromId(remoteId);
    String? firmware;
    String? manufacturer;
    String? modelNumber;
    int? battery;

    try {
      await device.connect(timeout: timeout, autoConnect: false);
      final services = await device.discoverServices();
      for (final service in services) {
        final uuid = service.uuid.str128.toLowerCase();
        if (uuid.startsWith('0000180a')) {
          // Device Information Service: read what is exposed; ignore
          // characteristics the watch does not implement.
          for (final char in service.characteristics) {
            final cuid = char.uuid.str128.toLowerCase();
            try {
              if (cuid.startsWith('00002a26')) {
                firmware = String.fromCharCodes(await char.read()).trim();
              } else if (cuid.startsWith('00002a29')) {
                manufacturer = String.fromCharCodes(await char.read()).trim();
              } else if (cuid.startsWith('00002a24')) {
                modelNumber = String.fromCharCodes(await char.read()).trim();
              }
            } catch (_) {
              // Some characteristics require auth — skip silently.
            }
          }
        } else if (uuid.startsWith('0000180f')) {
          for (final char in service.characteristics) {
            try {
              final bytes = await char.read();
              if (bytes.isNotEmpty) battery = bytes.first;
            } catch (_) {
              // Skip if not readable.
            }
          }
        }
      }
    } on FlutterBluePlusException catch (e) {
      // Connect/discover failed — return partial info so the caller can
      // still register the MAC. The UI explains the limitation.
      throw BleFailure(
        BleFailureReason.connectFailed,
        'Không đọc được thông tin chi tiết: ${e.description ?? e.toString()}',
        cause: e,
      );
    } finally {
      try {
        await device.disconnect();
      } catch (_) {
        // Best-effort cleanup.
      }
    }

    return BleConnectedDevice(
      remoteId: remoteId,
      name: device.platformName,
      batteryLevel: battery,
      firmwareRevision: firmware,
      manufacturer: manufacturer,
      modelNumber: modelNumber,
    );
  }
}
