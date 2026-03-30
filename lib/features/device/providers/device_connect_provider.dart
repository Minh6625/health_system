import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import 'package:healthguard/features/device/repositories/device_repository.dart';

enum DeviceConnectState {
  intro,              // Method select (QR or Manual)
  scanning,           // QR Scanner
  manualForm,         // Manual text entry
  verifying,          // Checking the QR/Code with backend
  confirmIdentity,    // Device recognized, awaiting user confirm
  pairing,            // Actually binding device to account
  success,            // Bind success
  error,              // QR invalid, Code invalid, etc.
}

class DeviceConnectProvider extends ChangeNotifier {
  final DeviceRepository _repository = DeviceRepository();

  DeviceConnectState _state = DeviceConnectState.intro;
  DeviceConnectState get state => _state;

  MockBleDevice? _identifiedDevice;
  MockBleDevice? get identifiedDevice => _identifiedDevice;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  bool _isPairing = false;
  bool get isPairing => _isPairing;

  // ── Actions ──────────────────────────────────────────────────────────────

  void openManualMode() {
    _state = DeviceConnectState.manualForm;
    notifyListeners();
  }

  void openQrScanner() {
    _state = DeviceConnectState.scanning;
    notifyListeners();

    // Auto-mock: simulate recognizing a QR code after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (_state == DeviceConnectState.scanning) {
        verifyCode('QR_SCANNED_MOCK_DATA');
      }
    });
  }

  void backToIntro() {
    _state = DeviceConnectState.intro;
    _errorMessage = null;
    _identifiedDevice = null;
    notifyListeners();
  }

  void verifyCode(String code) async {
    _state = DeviceConnectState.verifying;
    _errorMessage = null;
    notifyListeners();

    // Simulate network delay for verification
    await Future.delayed(const Duration(milliseconds: DeviceMockConfig.fakeApiDelayMs));

    if (code.isEmpty) {
      _state = DeviceConnectState.error;
      _errorMessage = 'Mã thiết bị không hợp lệ. Vui lòng kiểm tra lại.';
      notifyListeners();
      return;
    }

    // Success mock: grab the first device from discovery as the "identified" one
    _identifiedDevice = MockBleDiscovery.nearbyDevices.first.device;
    _state = DeviceConnectState.confirmIdentity;
    notifyListeners();
  }

  void confirmAndPair() async {
    if (_identifiedDevice == null) return;
    
    _state = DeviceConnectState.pairing;
    _isPairing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Call live API to pair device
      await _repository.pairNewDevice(
        macAddress: _identifiedDevice!.macAddress,
        deviceName: _identifiedDevice!.name,
        deviceType: _identifiedDevice!.deviceType,
        model: null,  // MockBleDevice doesn't have model
      );
      
      _state = DeviceConnectState.success;
      _isPairing = false;
      notifyListeners();
    } catch (e) {
      _state = DeviceConnectState.error;
      _errorMessage = 'Ghép nối thất bại: ${e.toString()}';
      _isPairing = false;
      notifyListeners();
    }
  }
}
