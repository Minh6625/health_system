import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';

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
  DeviceConnectState _state = DeviceConnectState.intro;
  DeviceConnectState get state => _state;

  MockBleDevice? _identifiedDevice;
  MockBleDevice? get identifiedDevice => _identifiedDevice;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
    notifyListeners();

    // Simulate pairing/binding delay
    await Future.delayed(const Duration(milliseconds: DeviceMockConfig.fakePairingDelayMs));

    _state = DeviceConnectState.success;
    notifyListeners();
  }
}
