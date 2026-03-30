import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import 'package:healthguard/features/device/repositories/device_repository.dart';

class DeviceConfigureProvider extends ChangeNotifier {
  final DeviceModel device;
  final DeviceRepository _repository = DeviceRepository();
  
  // Local state for the form
  late String deviceName;
  bool vibrationAlert = true;
  bool sleepTracking = true;
  double lowBatteryThreshold = 20.0;
  String syncInterval = '1h';

  // Dirty state tracking
  bool _isDirty = false;
  bool get isDirty => _isDirty;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isUnpairing = false;
  bool get isUnpairing => _isUnpairing;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DeviceConfigureProvider(this.device) {
    deviceName = device.displayName;
    // In a real app, you would fetch actual config from an endpoint here.
    // For now we use the initial values.
  }

  void updateName(String name) {
    if (deviceName != name) {
      deviceName = name;
      _markDirty();
    }
  }

  void updateVibration(bool value) {
    if (vibrationAlert != value) {
      vibrationAlert = value;
      _markDirty();
    }
  }

  void updateSleepTracking(bool value) {
    if (sleepTracking != value) {
      sleepTracking = value;
      _markDirty();
    }
  }

  void updateBatteryThreshold(double value) {
    if (lowBatteryThreshold != value) {
      lowBatteryThreshold = value;
      _markDirty();
    }
  }

  void updateSyncInterval(String value) {
    if (syncInterval != value) {
      syncInterval = value;
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

    try {
      // Call live API to update device settings
      await _repository.updateDeviceSettings(
        deviceId: device.id,
        calibrationData: {
          'notify_high_hr': vibrationAlert,
          'notify_low_spo2': sleepTracking,
          'notify_high_bp': vibrationAlert,
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

  Future<bool> unpairDevice() async {
    _isUnpairing = true;
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: DeviceMockConfig.fakeApiDelayMs));

    _isUnpairing = false;
    notifyListeners();
    return true; // Return true to indicate it was unpaired
  }
}
