import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/repositories/device_repository.dart';

class DeviceConfigureProvider extends ChangeNotifier {
  final DeviceModel device;
  final DeviceRepository _repository;

  DeviceConfigureProvider(this.device, {DeviceRepository? repository})
      : _repository = repository ?? DeviceRepository() {
    deviceName = device.displayName;
    // In a real app, you would fetch actual config from an endpoint here.
    // For now we use the initial values.
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
  // (`backend/app/schemas/device.py`). Defaults match the backend defaults
  // so the toggles render the same as a freshly-paired device until we plumb
  // existing calibration_data through DeviceModel (separate follow-up).
  late String deviceName;
  bool notifyHighHr = true;
  bool notifyLowSpo2 = true;
  bool notifyHighBp = true;

  // Dirty state tracking
  bool _isDirty = false;
  bool get isDirty => _isDirty;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isUnpairing = false;
  bool get isUnpairing => _isUnpairing;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
    if (!_isDirty) {
      _isDirty = true;
      notifyListeners();
    }
  }

  Future<bool> saveChanges() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    // Reject empty names up front so the user gets a clear Vietnamese
    // message instead of a 422 from the backend Pydantic validator.
    if (_nameDirty && deviceName.trim().isEmpty) {
      _isSaving = false;
      _errorMessage = 'Tên thiết bị không được để trống.';
      notifyListeners();
      return false;
    }

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
      _errorMessage = 'Lỗi: ${e.toString()}';
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
