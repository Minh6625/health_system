import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import 'package:healthguard/features/device/models/device_model.dart';

/// Provider for DEVICE_StatusDetail screen.
///
/// Supports two modes:
///   • **Live** (default): fetches `GET /api/mobile/devices/:id` from backend.
///   • **Mock** (`DeviceMockConfig.useMockData == true`): returns a pre-built
///     [DeviceModel] from [DeviceMockSnapshots] with a simulated delay.
///
/// Mock device IDs (see [DeviceMockSnapshots]):
///   101 → Normal / healthy device
///   102 → Low battery device   (battery < 20 %)
///   103 → Offline device
///   104 → Critical (offline + battery 5%)
///   105 → Sparse data (missing optional fields)
class DeviceStatusDetailProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final int deviceId;

  DeviceModel? _device;
  bool _isLoading = true;
  String? _errorMessage;

  DeviceStatusDetailProvider({required this.deviceId}) {
    fetchDeviceDetail();
  }

  DeviceModel? get device => _device;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fetchDeviceDetail() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (DeviceMockConfig.useMockData) {
      // ── Mock mode ──────────────────────────────────────────────────────
      await Future.delayed(
        Duration(milliseconds: DeviceMockConfig.fakeApiDelayMs),
      );
      _device = DeviceMockSnapshots.getById(deviceId);
      _isLoading = false;
      notifyListeners();
      return;
    }

    // ── Live mode ────────────────────────────────────────────────────────
    try {
      final response =
          await _apiClient.get('${ApiEndpoints.devices}/$deviceId');
      _device = DeviceModel.fromJson(response);
    } catch (e) {
      if (e.toString().contains('404')) {
        _errorMessage = 'Thiết bị không còn tồn tại.';
      } else {
        _errorMessage = 'Không thể tải chi tiết thiết bị: ${e.toString()}';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seed provider with an existing snapshot (e.g., from DEVICE_List cache).
  /// Does NOT abort a live fetch in progress.
  void syncWithExisting(DeviceModel existingDevice) {
    if (_device == null) {
      _device = existingDevice;
      _isLoading = false;
      notifyListeners();
    }
  }
}
