import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/repositories/device_repository.dart';

class DeviceConfigureProvider extends ChangeNotifier {
  final DeviceModel device;
  final DeviceRepository _repository;

  DeviceConfigureProvider(this.device, {DeviceRepository? repository})
      : _repository = repository ?? DeviceRepository() {
    deviceName = device.displayName;
    // Seed the three notification toggles from the device's persisted
    // calibration_data so the screen opens with whatever the user previously
    // saved. Falls back to the backend defaults (`true`) for keys that are
    // missing or for devices that have never been configured.
    final calibration = device.calibrationData;
    notifyHighHr = _readBool(calibration, 'notify_high_hr', defaultValue: true);
    notifyLowSpo2 =
        _readBool(calibration, 'notify_low_spo2', defaultValue: true);
    notifyHighBp = _readBool(calibration, 'notify_high_bp', defaultValue: true);
  }

  static bool _readBool(
    Map<String, dynamic>? source,
    String key, {
    required bool defaultValue,
  }) {
    if (source == null) return defaultValue;
    final raw = source[key];
    if (raw is bool) return raw;
    return defaultValue;
  }

  // Tracks whether the user explicitly typed a different name in the
  // TextField. We need this separate from `_isDirty` because the initial
  // `deviceName` is `device.displayName`, which is a synthetic fallback for
  // devices whose backend `device_name` is null. Saving the synthetic
  // fallback as the real name without explicit user intent would be a
  // regression, so we only PATCH when this flag is true.
  bool _nameDirty = false;

  // Local state for the form. The three notify_* booleans correspond 1:1
  // to the backend `DeviceSettingsRequest` schema
  // (`backend/app/schemas/device.py`) and are seeded from the device's
  // persisted `calibration_data` in the constructor.
  late String deviceName;
  late bool notifyHighHr;
  late bool notifyLowSpo2;
  late bool notifyHighBp;

  // Dirty state tracking
  bool _isDirty = false;
  bool get isDirty => _isDirty;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isUnpairing = false;
  bool get isUnpairing => _isUnpairing;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // F-7 (M-7): true when the most recent saveChanges() committed the name
  // PATCH but the settings PUT then failed. The screen reads this flag to
  // pick a warning-tinted snackbar instead of the misleading red error that
  // QA reported (the rename DID persist; only the toggles need a retry).
  // Cleared at the start of every saveChanges() call.
  bool _hasPartialSuccess = false;
  bool get hasPartialSuccess => _hasPartialSuccess;

  void updateName(String name) {
    if (deviceName != name) {
      deviceName = name;
      _nameDirty = true;
      _markDirty();
    }
  }

  void updateNotifyHighHr(bool value) {
    if (notifyHighHr != value) {
      notifyHighHr = value;
      _markDirty();
    }
  }

  void updateNotifyLowSpo2(bool value) {
    if (notifyLowSpo2 != value) {
      notifyLowSpo2 = value;
      _markDirty();
    }
  }

  void updateNotifyHighBp(bool value) {
    if (notifyHighBp != value) {
      notifyHighBp = value;
      _markDirty();
    }
  }

  void _markDirty() {
    // Bug 2 (QA): the original implementation only called notifyListeners()
    // on the false→true transition, so every subsequent toggle was silent.
    // SwitchListTile is a controlled widget driven by `provider.notifyXxx`,
    // so without a notify the UI didn't rebuild and the switch appeared
    // "stuck" — exactly the "tắt cảnh báo nhịp tim cao xong bật lại không
    // được" symptom. Each updateNotifyXxx caller already guards with
    // `if (current != value)` so there are no spurious notifies; we always
    // notify here to keep the switches in sync with the provider state.
    _isDirty = true;
    notifyListeners();
  }

  Future<bool> saveChanges() async {
    _isSaving = true;
    _errorMessage = null;
    _hasPartialSuccess = false;
    notifyListeners();

    // Reject empty names up front so the user gets a clear Vietnamese
    // message instead of a 422 from the backend Pydantic validator.
    if (_nameDirty && deviceName.trim().isEmpty) {
      _isSaving = false;
      _errorMessage = 'Tên thiết bị không được để trống.';
      notifyListeners();
      return false;
    }

    // F-7 (M-7): track per-step success so the catch block can tell a clean
    // failure ("both calls failed") from a partial success ("name persisted,
    // only settings PUT failed"). Without this distinction the user got a
    // red snackbar even though their rename was already committed.
    bool nameJustCommitted = false;

    try {
      // 1) PATCH the device name when the user actually edited it. We do
      //    this first so a server-side validation error (e.g. duplicate /
      //    too long) surfaces before we touch settings.
      if (_nameDirty) {
        await _repository.updateDeviceName(
          deviceId: device.id,
          deviceName: deviceName.trim(),
        );
        _nameDirty = false;
        nameJustCommitted = true;
      }

      // 2) PUT the three notify flags using backend keys directly.
      //    Previously saveChanges aliased UI fields onto wrong keys
      //    (vibrationAlert -> notify_high_hr AND notify_high_bp,
      //    sleepTracking -> notify_low_spo2) and silently dropped a battery
      //    slider and a sync dropdown. The new payload matches
      //    DeviceSettingsRequest 1:1.
      await _repository.updateDeviceSettings(
        deviceId: device.id,
        calibrationData: {
          'notify_high_hr': notifyHighHr,
          'notify_low_spo2': notifyLowSpo2,
          'notify_high_bp': notifyHighBp,
        },
      );

      _isSaving = false;
      _isDirty = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      if (nameJustCommitted) {
        // F-7 (M-7): partial success — the rename PATCH already committed on
        // the server, only the settings PUT failed. Surface that honestly so
        // the screen can show a warning snackbar (not a red "everything
        // failed" error) and the user only retries the settings step.
        // _nameDirty was cleared after the PATCH so a retry will skip the
        // already-committed name change automatically.
        _hasPartialSuccess = true;
        _errorMessage =
            'Đã đổi tên thiết bị, nhưng chưa lưu được cài đặt thông báo: '
            '${e.toString()}';
      } else {
        _errorMessage = 'Lỗi: ${e.toString()}';
      }
      notifyListeners();
      return false;
    }
  }

  /// Unpair device against the live backend (`DELETE /devices/{id}`).
  ///
  /// Replaces a previous fake-delay-only implementation that always returned
  /// `true`, leaving the device record on the server while the UI showed a
  /// success message. We now propagate failure via [errorMessage] so the
  /// danger-zone dialog can surface a real error.
  Future<bool> unpairDevice() async {
    _isUnpairing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.unpairDevice(device.id);
      _isUnpairing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isUnpairing = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      notifyListeners();
      return false;
    }
  }
}
