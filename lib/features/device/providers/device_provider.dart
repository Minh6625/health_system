import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/device/models/device_model.dart';

class DeviceProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<DeviceModel> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = 'all';
  String? _typeFilter;
  int _total = 0;

  List<DeviceModel> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get onlineCount => _devices.where((device) => device.isOnline).length;
  String get statusFilter => _statusFilter;
  String? get typeFilter => _typeFilter;
  int get total => _total;

  Future<void> setStatusFilter(String value) async {
    _statusFilter = value;
    await fetchDevices();
  }

  Future<void> setTypeFilter(String? value) async {
    _typeFilter = value;
    await fetchDevices();
  }

  Future<bool> updateDevice({
    required int deviceId,
    String? deviceName,
    String? firmwareVersion,
    bool? isActive,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiClient.patch(
        '${ApiEndpoints.devices}/$deviceId',
        body: {
          'device_name': deviceName,
          'firmware_version': firmwareVersion,
          'is_active': isActive,
        },
      );

      final updated = DeviceModel.fromJson(result);
      _devices = _devices
          .map((device) => device.id == deviceId ? updated : device)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Khong the cap nhat thiet bi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDevice(int deviceId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.delete('${ApiEndpoints.devices}/$deviceId');
      _devices = _devices.where((device) => device.id != deviceId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Khong the xoa thiet bi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addDevice({
    required String deviceName,
    required String deviceType,
    String? model,
    String? firmwareVersion,
    String? macAddress,
    String? serialNumber,
    String? mqttClientId,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiClient.post(
        ApiEndpoints.devices,
        body: {
          'device_name': deviceName,
          'device_type': deviceType,
          'model': model,
          'firmware_version': firmwareVersion,
          'mac_address': macAddress,
          'serial_number': serialNumber,
          'mqtt_client_id': mqttClientId,
        },
      );

      _devices = [DeviceModel.fromJson(result), ..._devices];
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Khong the them thiet bi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final query = <String, String>{
        'status': _statusFilter,
        'limit': '100',
        'offset': '0',
      };
      if (_typeFilter != null && _typeFilter!.isNotEmpty) {
        query['device_type'] = _typeFilter!;
      }

      final queryString = query.entries
          .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
          .join('&');

      final response = await _apiClient.get('${ApiEndpoints.devices}?$queryString');
      final rawDevices = response['devices'] as List<dynamic>? ?? [];
      _total = (response['total'] as num?)?.toInt() ?? rawDevices.length;
      _devices = rawDevices
          .whereType<Map<String, dynamic>>()
          .map(DeviceModel.fromJson)
          .toList();
    } catch (e) {
      _errorMessage = 'Khong the tai danh sach thiet bi: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
