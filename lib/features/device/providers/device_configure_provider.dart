import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';

class DeviceConfigureProvider extends ChangeNotifier {
  final DeviceModel device;
  
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
    notifyListeners();

    // Simulate API call
    await Future.delayed(const Duration(milliseconds: DeviceMockConfig.fakeApiDelayMs));

    _isSaving = false;
    _isDirty = false;
    notifyListeners();
    return true; // Return true to indicate success
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
