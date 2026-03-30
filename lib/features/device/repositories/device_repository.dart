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
