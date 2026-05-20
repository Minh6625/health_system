// lib/features/device/providers/health_sync_provider.dart
//
// Phase 2: foreground polling provider that drives the
// `Mi Fitness -> Health Connect -> backend` pipeline.
//
// Behaviour contract:
//   * `start()` triggers an immediate sync, then polls every 60s while
//     the host screen is mounted. Stops on `dispose()` so background
//     screens never burn battery.
//   * `manualRefresh()` runs the same sync path but exposes loading
//     state for pull-to-refresh / explicit "Đồng bộ ngay" buttons.
//   * `lastSyncAt` is persisted to `shared_preferences` keyed by
//     userId+deviceId. The next `start()` resumes from that watermark
//     so we never re-fetch the full 24h window unnecessarily.
//
// Out of scope: WorkManager-style background sync. The product decision
// (anh chốt 2026-05-20) was foreground polling + manual refresh only —
// good enough for demo, no battery cost when the app is closed.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthguard/core/services/health_connect_service.dart';
import 'package:healthguard/features/device/repositories/health_connect_repository.dart';

enum HealthSyncState {
  idle,
  syncing,
  success,
  error,
  permissionRequired,
  notInstalled,
}

class HealthSyncProvider extends ChangeNotifier {
  HealthSyncProvider({
    HealthConnectService? service,
    HealthConnectRepository? repository,
    Duration pollInterval = const Duration(seconds: 60),
    Duration initialWindow = const Duration(hours: 24),
  })  : _service = service ?? HealthConnectService.instance,
        _repository = repository ?? HealthConnectRepository(),
        _pollInterval = pollInterval,
        _initialWindow = initialWindow;

  final HealthConnectService _service;
  final HealthConnectRepository _repository;
  final Duration _pollInterval;
  final Duration _initialWindow;

  Timer? _timer;
  bool _isSyncing = false;
  bool _disposed = false;

  HealthSyncState _state = HealthSyncState.idle;
  HealthSyncState get state => _state;

  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;

  int _lastBatchAccepted = 0;
  int _lastBatchRejected = 0;
  int _lastBatchSent = 0;
  int get lastBatchAccepted => _lastBatchAccepted;
  int get lastBatchRejected => _lastBatchRejected;
  int get lastBatchSent => _lastBatchSent;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int? _activeDeviceId;
  int? get activeDeviceId => _activeDeviceId;

  /// Begin polling for [deviceId]. Idempotent — calling with the same
  /// device just resets the timer; calling with a different device
  /// stops the previous poll first.
  Future<void> start(int deviceId) async {
    if (_activeDeviceId == deviceId && _timer != null) return;
    _activeDeviceId = deviceId;
    _timer?.cancel();
    await _restoreLastSyncAt();
    await _runSync(initial: true);
    _timer = Timer.periodic(_pollInterval, (_) => _runSync());
  }

  /// User-driven sync trigger. Bypasses the inflight guard so a manual
  /// pull-to-refresh always feels responsive.
  Future<void> manualRefresh() async {
    if (_activeDeviceId == null) return;
    await _runSync(force: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runSync({bool initial = false, bool force = false}) async {
    final deviceId = _activeDeviceId;
    if (deviceId == null) return;
    if (_isSyncing && !force) return;

    _isSyncing = true;
    _state = HealthSyncState.syncing;
    _errorMessage = null;
    _safeNotify();

    try {
      final availability = await _service.checkAvailability();
      if (availability == HealthConnectAvailability.notInstalled ||
          availability == HealthConnectAvailability.needsUpdate) {
        _state = HealthSyncState.notInstalled;
        _safeNotify();
        return;
      }
      final permState = await _service.hasPermissions();
      if (permState == HealthPermissionState.denied) {
        _state = HealthSyncState.permissionRequired;
        _safeNotify();
        return;
      }

      final since = _lastSyncAt ?? DateTime.now().subtract(_initialWindow);
      final result = await _repository.syncSince(
        deviceId: deviceId,
        since: since,
      );

      _lastBatchAccepted = result.accepted;
      _lastBatchRejected = result.rejected;
      _lastBatchSent = result.sentSamples;
      _lastSyncAt = DateTime.now();
      await _persistLastSyncAt();
      _state = HealthSyncState.success;
    } catch (e, st) {
      debugPrint('HealthSync failed: $e\n$st');
      _state = HealthSyncState.error;
      _errorMessage = e.toString();
    } finally {
      _isSyncing = false;
      _safeNotify();
    }
  }

  String _prefsKey() => 'hc_last_sync_at_${_activeDeviceId ?? 0}';

  Future<void> _persistLastSyncAt() async {
    final ts = _lastSyncAt;
    if (ts == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(), ts.toUtc().toIso8601String());
  }

  Future<void> _restoreLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey());
    if (raw == null) return;
    _lastSyncAt = DateTime.tryParse(raw);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
