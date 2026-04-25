import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/device/models/device_model.dart';

class DeviceRepository {
  final ApiClient _apiClient = ApiClient();

  /// Pair new device via BLE scan - POST /devices/scan/pair
  Future<DeviceModel> pairNewDevice({
    required String macAddress,
    required String deviceName,
    required String deviceType,
    String? model,
  }) async {
    try {
      final result = await _apiClient.post(
        '/devices/scan/pair',
        body: {
          'mac_address': macAddress,
          'device_name': deviceName,
          'device_type': deviceType,
          if (model != null) 'model': model,
        },
        requiresAuth: true,
      );
      
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Ghép nối thiết bị thất bại');
      }
      
      // Parse device from response
      if (result['device'] != null) {
        return DeviceModel.fromJson(result['device'] as Map<String, dynamic>);
      }
      throw Exception('Không nhận được dữ liệu thiết bị');
    } catch (e) {
      rethrow;
    }
  }

  /// Update mutable device metadata such as the user-facing name -
  /// PATCH /devices/{id}.
  ///
  /// The backend `DeviceUpdateRequest` schema only accepts
  /// `device_name`, `firmware_version`, and `is_active`. We surface only
  /// `device_name` here because that is the single field the configure
  /// screen exposes to the user. Throws on non-2xx so the provider can
  /// keep the form dirty and surface the error message instead of
  /// pretending the name was saved.
  Future<DeviceModel> updateDeviceName({
    required int deviceId,
    required String deviceName,
  }) async {
    final result = await _apiClient.patch(
      '/devices/$deviceId',
      body: {'device_name': deviceName},
      requiresAuth: true,
    );

    if (result is! Map<String, dynamic>) {
      throw Exception('Phản hồi không hợp lệ khi cập nhật tên thiết bị');
    }
    return DeviceModel.fromJson(result);
  }

  /// Update device settings - PUT /devices/{id}/settings
  Future<Map<String, dynamic>> updateDeviceSettings({
    required int deviceId,
    Map<String, dynamic>? calibrationData,
  }) async {
    try {
      final result = await _apiClient.put(
        '/devices/$deviceId/settings',
        body: calibrationData ?? {},
        requiresAuth: true,
      );
      
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Cập nhật cấu hình thất bại');
      }
      
      return result['calibration_data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      rethrow;
    }
  }

  /// Unpair device - DELETE /devices/{id}
  ///
  /// Calls the live backend `delete_device` endpoint
  /// (`backend/app/api/routes/device.py:113`). Throws on non-success so the
  /// caller can surface a real error instead of a silent fake "thành công".
  Future<void> unpairDevice(int deviceId) async {
    final result = await _apiClient.delete(
      '/devices/$deviceId',
      requiresAuth: true,
    );

    if (result is! Map<String, dynamic> || result['success'] != true) {
      final message = result is Map<String, dynamic>
          ? (result['message'] as String?)
          : null;
      throw Exception(message ?? 'Hủy ghép nối thiết bị thất bại');
    }
  }

  /// Get device list - reuse from DeviceProvider or add here
  Future<List<DeviceModel>> getDeviceList({
    String? status = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final result = await _apiClient.get(
        '/devices',
        queryParams: {
          'status': status,
          'limit': limit,
          'offset': offset,
        },
        requiresAuth: true,
      );
      
      final devicesList = (result['devices'] as List? ?? [])
          .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
          .toList();
      
      return devicesList;
    } catch (e) {
      rethrow;
    }
  }
}
