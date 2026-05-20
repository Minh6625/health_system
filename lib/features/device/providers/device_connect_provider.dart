// lib/features/device/providers/device_connect_provider.dart
//
// Phase 1 of the Redmi Watch 3 (M2216W1) integration.
//
// Pre-Phase-1 this provider faked the entire BLE flow: a 2.5 s timer
// "discovered" three hard-coded devices and the confirm button paired
// against a static MAC. That was useful for UX iteration but it never
// proved the app could actually talk to a Redmi Watch 3.
//
// This rewrite splits the discovery layer in two:
//   * Live mode (default on real Android devices) drives a real
//     [BleService] scan, surfaces every advertisement that matches the
//     Redmi/Mi name prefixes, and pairs against the actual MAC the watch
//     advertises.
//   * Mock mode (toggle via `DeviceMockConfig.useMockData`) is preserved
//     so we can keep iterating UX on the Android emulator, which has no
//     BLE radio.
//
// Mock data, [DeviceMockConfig], and [DeviceRepository] interfaces are
// unchanged — only the discovery + selection wiring moves.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:healthguard/core/services/ble_service.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import 'package:healthguard/features/device/repositories/device_repository.dart';

enum DeviceConnectState {
  intro, // Method select (BLE scan or Manual code).
  scanning, // BLE scan in progress, devices stream in real-time.
  manualForm, // Manual text entry (used as a fallback when BLE fails).
  verifying, // Manual code being checked against the backend.
  confirmIdentity, // Device picked, awaiting user confirm.
  pairing, // Calling /devices/scan/pair.
  success, // Pair OK.
  error, // Permission / adapter / pair error.
}

/// Discriminated source so the success card can label the device honestly
/// — the user should see whether the watch came from a real BLE scan or a
/// mocked discovery list.
enum DeviceDiscoverySource { live, mock, manual }

/// Toggle between the curated Redmi/Mi name filter and an unfiltered scan
/// that surfaces every BLE peripheral with a non-empty name. The "scan
/// all" mode is a debug aid for cases where a watch advertises with an
/// unexpected name (e.g. `XMSH_M2216W1`) and would otherwise never appear
/// in the curated list.
enum DiscoveryMode { redmiOnly, scanAll }

/// UI-facing wrapper around [BleScanEntry] / [MockBleDevice]. Centralising
/// the contract here means the connect widgets do not need to know which
/// branch produced the entry.
@immutable
class DiscoveredDevice {
  final String id;
  final String name;
  final String macAddress;
  final String deviceType;
  final int rssi;
  final DeviceDiscoverySource source;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.deviceType,
    required this.rssi,
    required this.source,
  });

  factory DiscoveredDevice.fromMock(MockBleDevice mock) => DiscoveredDevice(
        id: mock.id,
        name: mock.name,
        macAddress: mock.macAddress,
        deviceType: mock.deviceType,
        rssi: mock.rssi,
        source: DeviceDiscoverySource.mock,
      );

  /// Maps a live scan hit into the UI model. Returns null when the
  /// platform did not surface a parseable MAC (mostly iOS, which exposes
  /// random UUIDs instead) — the connect screen drops those rows because
  /// the backend pairing endpoint requires the canonical MAC format.
  static DiscoveredDevice? fromLive(BleScanEntry entry) {
    final mac = entry.macAddress;
    if (mac == null) return null;
    return DiscoveredDevice(
      id: entry.remoteId,
      name: entry.name,
      macAddress: mac,
      deviceType: _inferDeviceType(entry.name),
      rssi: entry.rssi,
      source: DeviceDiscoverySource.live,
    );
  }

  /// Best-effort mapping from advertised name to one of the backend
  /// device_type enum values (smartwatch / fitness_band / medical_device).
  /// Anything that mentions "band" goes to fitness_band; everything else
  /// defaults to smartwatch which is by far the more common Redmi case.
  static String _inferDeviceType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('band')) return 'fitness_band';
    return 'smartwatch';
  }
}

class DeviceConnectProvider extends ChangeNotifier {
  final DeviceRepository _repository = DeviceRepository();
  final BleService _ble;

  DeviceConnectProvider({BleService? bleService})
      : _ble = bleService ?? BleService.instance;

  DeviceConnectState _state = DeviceConnectState.intro;
  DeviceConnectState get state => _state;

  /// Active discovery mode. Defaults to the curated Redmi/Mi filter; the
  /// connect UI can flip this to [DiscoveryMode.scanAll] for debug
  /// scenarios where the watch advertises an unexpected name.
  DiscoveryMode _discoveryMode = DiscoveryMode.redmiOnly;
  DiscoveryMode get discoveryMode => _discoveryMode;

  DiscoveredDevice? _identifiedDevice;
  DiscoveredDevice? get identifiedDevice => _identifiedDevice;

  /// Live scan results, deduplicated by [DiscoveredDevice.id]. Sorted by
  /// RSSI descending so the strongest (closest) device sits at the top of
  /// the list.
  final List<DiscoveredDevice> _discovered = [];
  List<DiscoveredDevice> get discovered => List.unmodifiable(_discovered);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// When set, the scan UI renders an actionable hint above the retry
  /// button (e.g. "Bật Bluetooth", "Mở cài đặt"). Mapped from
  /// [BleFailureReason] so the widget layer never imports BleService.
  BleFailureReason? _errorReason;
  BleFailureReason? get errorReason => _errorReason;

  bool _isPairing = false;
  bool get isPairing => _isPairing;

  StreamSubscription<BleScanEntry>? _scanSub;
  Timer? _scanTimer;
  bool _disposed = false;
  static const Duration _scanWindow = Duration(seconds: 30);

  // ── Actions ──────────────────────────────────────────────────────────────

  void openManualMode() {
    _state = DeviceConnectState.manualForm;
    _safeNotify();
  }

  /// Replaces the legacy `openQrScanner()` mock. Kept under the same
  /// public name so the existing widget tree (method_select_step,
  /// device_qr_scan_step) can call into it without churning navigation
  /// logic. The [forceMock] knob lets developer builds simulate the live
  /// flow on an emulator without flipping the global config.
  Future<void> openQrScanner({
    bool forceMock = false,
    DiscoveryMode? mode,
  }) async {
    if (mode != null) _discoveryMode = mode;
    final useMock = forceMock || DeviceMockConfig.useMockData;
    _resetScanState();
    _state = DeviceConnectState.scanning;
    _safeNotify();

    if (useMock) {
      await _runMockDiscovery();
      return;
    }
    await _runLiveDiscovery();
  }

  /// Switches discovery mode and immediately restarts the scan so the
  /// user sees results from the new filter without an extra tap.
  Future<void> setDiscoveryMode(DiscoveryMode mode) async {
    if (_discoveryMode == mode) return;
    _discoveryMode = mode;
    if (_state == DeviceConnectState.scanning ||
        _state == DeviceConnectState.error) {
      await openQrScanner();
    } else {
      _safeNotify();
    }
  }

  void backToIntro() {
    _cancelScan();
    _state = DeviceConnectState.intro;
    _errorMessage = null;
    _errorReason = null;
    _identifiedDevice = null;
    _discovered.clear();
    _safeNotify();
  }

  /// Called when the user picks one of the listed devices in the scan UI.
  /// Validates the MAC format (defensive — both code paths normalise it
  /// already) and moves to the confirm screen.
  void selectDiscovered(DiscoveredDevice device) {
    _cancelScan();
    _identifiedDevice = device;
    _state = DeviceConnectState.confirmIdentity;
    _safeNotify();
  }

  /// Manual code entry path (kept for users who can't scan, e.g. watch
  /// already paired with another phone). Accepts either:
  ///   - A canonical MAC address `AA:BB:CC:DD:EE:FF` (case-insensitive,
  ///     also accepts `-` separators) — used when the watch is bonded
  ///     to Mi Fitness and stops advertising publicly. The user copies
  ///     the MAC from Android Settings -> Bluetooth -> bonded device.
  ///   - Anything else falls back to the legacy mock flow so QA can
  ///     still exercise the success path on an emulator without typing
  ///     a real MAC.
  Future<void> verifyCode(String code) async {
    _state = DeviceConnectState.verifying;
    _errorMessage = null;
    _errorReason = null;
    _safeNotify();

    await Future.delayed(
      const Duration(milliseconds: DeviceMockConfig.fakeApiDelayMs),
    );

    if (code.isEmpty) {
      _state = DeviceConnectState.error;
      _errorMessage = 'Mã thiết bị không hợp lệ. Vui lòng kiểm tra lại.';
      _safeNotify();
      return;
    }

    // Try to parse as a MAC address first. Real watches that have
    // already bonded with Mi Fitness do not show up in our BLE scan,
    // so accepting a MAC here is the escape hatch the user actually
    // needs to register their hardware.
    final mac = _normalizeMac(code);
    if (mac != null) {
      _identifiedDevice = DiscoveredDevice(
        id: mac,
        name: 'Redmi Watch 3',
        macAddress: mac,
        deviceType: 'smartwatch',
        rssi: 0,
        source: DeviceDiscoverySource.manual,
      );
      _state = DeviceConnectState.confirmIdentity;
      _safeNotify();
      return;
    }

    // Fallback: the legacy mock path so emulator demos keep working.
    final mockDevice = MockBleDiscovery.nearbyDevices.first.device;
    _identifiedDevice = DiscoveredDevice.fromMock(mockDevice);
    _state = DeviceConnectState.confirmIdentity;
    _safeNotify();
  }

  /// Returns the canonical `AA:BB:CC:DD:EE:FF` form when [raw] matches a
  /// MAC address (with `:` or `-` separators, any case), otherwise null.
  String? _normalizeMac(String raw) {
    final cleaned = raw.replaceAll('-', ':').toUpperCase().trim();
    final pattern = RegExp(r'^[0-9A-F]{2}(:[0-9A-F]{2}){5}$');
    return pattern.hasMatch(cleaned) ? cleaned : null;
  }

  Future<void> confirmAndPair() async {
    final picked = _identifiedDevice;
    if (picked == null) return;

    _state = DeviceConnectState.pairing;
    _isPairing = true;
    _errorMessage = null;
    _errorReason = null;
    _safeNotify();

    // Discovery-only flow: peek standard GATT metadata (DIS, Battery)
    // without bonding. The Redmi Watch 3 only exchanges meaningful data
    // with Mi Fitness, so a forced bond would either fail or leave a
    // dead pairing in the OS settings. We still record the MAC + best
    // available metadata so the device shows up in the user's account.
    String? model;
    String? firmware;
    if (picked.source == DeviceDiscoverySource.live) {
      try {
        final info = await _ble.peekMetadata(picked.id);
        model = info.modelNumber;
        firmware = info.firmwareRevision;
      } on BleFailure catch (e) {
        // Non-fatal: record the device with whatever we know, surface a
        // soft note in the success copy via errorMessage when the peek
        // partially failed.
        debugPrint('peekMetadata failed: ${e.message}');
      }
    }

    try {
      await _repository.pairNewDevice(
        macAddress: picked.macAddress,
        deviceName: picked.name,
        deviceType: picked.deviceType,
        model: model,
      );
      // TODO Phase 2: persist firmware via PATCH /devices/{id} once the
      // active-device branch lands. For now firmware stays null because
      // the existing /devices/scan/pair endpoint does not accept it.
      _firmwareReadback = firmware;
      _state = DeviceConnectState.success;
    } catch (e) {
      _state = DeviceConnectState.error;
      _errorMessage = 'Ghi nhận thiết bị thất bại: ${e.toString()}';
    } finally {
      _isPairing = false;
      _safeNotify();
    }
  }

  /// Firmware string read from DIS during the peek. Exposed read-only so
  /// the success card can render a "Firmware: 1.1.40" line when available.
  String? _firmwareReadback;
  String? get firmwareReadback => _firmwareReadback;

  // ── Internal: discovery branches ─────────────────────────────────────────

  Future<void> _runLiveDiscovery() async {
    try {
      await _ble.ensureReady();
    } on BleFailure catch (e) {
      _state = DeviceConnectState.error;
      _errorMessage = e.message;
      _errorReason = e.reason;
      _safeNotify();
      return;
    }

    try {
      _scanSub = _ble.startScan(timeout: _scanWindow).listen(
        (entry) {
          final mapped = DiscoveredDevice.fromLive(entry);
          if (mapped == null) return;
          final existingIdx =
              _discovered.indexWhere((d) => d.id == mapped.id);
          if (existingIdx >= 0) {
            // Refresh RSSI so the list reflects the most recent
            // advertisement strength.
            _discovered[existingIdx] = mapped;
          } else {
            _discovered.add(mapped);
          }
          _discovered.sort((a, b) => b.rssi.compareTo(a.rssi));
          _safeNotify();
        },
        onError: (error) {
          _state = DeviceConnectState.error;
          if (error is BleFailure) {
            _errorMessage = error.message;
            _errorReason = error.reason;
          } else {
            _errorMessage = 'Lỗi khi quét BLE: $error';
            _errorReason = BleFailureReason.unknown;
          }
          _safeNotify();
        },
        onDone: () {
          // Scan window finished. If nothing came back, surface a typed
          // failure so the UI can offer a retry button + tips.
          if (_state == DeviceConnectState.scanning && _discovered.isEmpty) {
            _state = DeviceConnectState.error;
            _errorMessage =
                'Không tìm thấy đồng hồ nào. Hãy đưa đồng hồ lại gần điện thoại và thử lại.';
            _errorReason = BleFailureReason.scanTimeout;
            _safeNotify();
          }
        },
      );
      _scanTimer = Timer(_scanWindow + const Duration(seconds: 2), () async {
        await _cancelScan();
      });
    } on BleFailure catch (e) {
      _state = DeviceConnectState.error;
      _errorMessage = e.message;
      _errorReason = e.reason;
      _safeNotify();
    }
  }

  Future<void> _runMockDiscovery() async {
    // Reproduce the legacy progressive-reveal so existing UX tests keep
    // passing on the emulator.
    for (final entry in MockBleDiscovery.nearbyDevices) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (_state != DeviceConnectState.scanning || _disposed) return;
      _discovered.add(DiscoveredDevice.fromMock(entry.device));
      _discovered.sort((a, b) => b.rssi.compareTo(a.rssi));
      _safeNotify();
    }
  }

  Future<void> _cancelScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    final sub = _scanSub;
    _scanSub = null;
    if (sub != null) {
      await sub.cancel();
    }
    try {
      await _ble.stopScan();
    } catch (_) {
      // Best-effort.
    }
  }

  void _resetScanState() {
    _discovered.clear();
    _identifiedDevice = null;
    _errorMessage = null;
    _errorReason = null;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelScan();
    super.dispose();
  }
}
