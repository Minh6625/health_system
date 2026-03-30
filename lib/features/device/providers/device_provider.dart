import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import 'package:healthguard/features/device/models/device_model.dart';

class DeviceProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  static const Duration _cacheTTL = Duration(seconds: 30);

  List<DeviceModel> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter = 'all';
  String? _typeFilter;
  int _total = 0;
  DateTime? _lastFetchTime;

  List<DeviceModel> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get onlineCount => _devices.where((device) => device.isOnline).length;
  String get statusFilter => _statusFilter;
  String? get typeFilter => _typeFilter;
  int get total => _total;

  /// Find devices that require user attention (offline, low battery, no sync)
  List<DeviceModel> get needsAttentionDevices =>
      _devices.where((d) => _deviceNeedsAttention(d)).toList();

  bool _deviceNeedsAttention(DeviceModel device) {
    final batteryLevel = device.batteryLevel;
    if (batteryLevel != null && batteryLevel <= 20) {
      return true;
    }

    final lastSyncAt = device.lastSyncAt;
    if (device.isActive && lastSyncAt != null) {
      final syncedRecently = DateTime.now().difference(lastSyncAt).inHours < 24;
      if (syncedRecently) {
        return false;
      }
    }

    if (device.isActive && lastSyncAt == null) {
      return true;
    }

    if (lastSyncAt != null && DateTime.now().difference(lastSyncAt).inHours >= 24) {
      return true;
    }

    return false;
  }

  Future<void> setStatusFilter(String value) async {
    _statusFilter = value;
    await fetchDevices(forceRefresh: true);
  }

  Future<void> setTypeFilter(String? value) async {
    _typeFilter = value;
    await fetchDevices(forceRefresh: true);
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

  void _sortDevices(List<DeviceModel> list) {
    list.sort((a, b) {
      final aNeedsAtt = _deviceNeedsAttention(a);
      final bNeedsAtt = _deviceNeedsAttention(b);
      if (aNeedsAtt && !bNeedsAtt) return -1;
      if (!aNeedsAtt && bNeedsAtt) return 1;
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return a.id.compareTo(b.id);
    });
  }

  bool _isCacheValid() {
    if (_lastFetchTime == null) {
      return false;
    }
    return DateTime.now().difference(_lastFetchTime!) < _cacheTTL;
  }

  Future<void> fetchDevices({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) {
      return;
    }

    final shouldNotifyLoading = _devices.isEmpty || forceRefresh;
    _isLoading = true;
    _errorMessage = null;
    if (shouldNotifyLoading) {
      notifyListeners();
    }

    if (DeviceMockConfig.useMockData) {
      // ── Mock mode ──────────────────────────────────────────────────────
      await Future.delayed(
        Duration(milliseconds: DeviceMockConfig.fakeApiDelayMs),
      );
      
      var mockList = <DeviceModel>[];
      switch (DeviceMockConfig.listScenario) {
        case MockListScenario.empty:
          mockList = [];
          break;
        case MockListScenario.error:
          _errorMessage = 'Mock lỗi API: Không thể tải danh sách thiết bị.';
          _isLoading = false;
          notifyListeners();
          return;
        case MockListScenario.allOffline:
          mockList = DeviceMockSnapshots.all.map((d) => DeviceModel(
            id: d.id, uuid: d.uuid, deviceName: d.deviceName, deviceType: d.deviceType,
            model: d.model, firmwareVersion: d.firmwareVersion, macAddress: d.macAddress,
            serialNumber: d.serialNumber, mqttClientId: d.mqttClientId,
            isActive: d.isActive, isOnline: false, batteryLevel: d.batteryLevel,
            signalStrength: d.signalStrength, lastSeenAt: d.lastSeenAt,
            lastSyncAt: d.lastSyncAt, registeredAt: d.registeredAt,
          )).toList();
          break;
        case MockListScenario.normal:
          mockList = List<DeviceModel>.from(DeviceMockSnapshots.all);
          break;
      }

      // Apply status filter
      if (_statusFilter == 'online') {
        mockList = mockList.where((d) => d.isOnline).toList();
      } else if (_statusFilter == 'offline') {
        mockList = mockList.where((d) => !d.isOnline).toList();
      }

      // Apply type filter
      if (_typeFilter != null && _typeFilter!.isNotEmpty) {
        mockList = mockList.where((d) => d.deviceType == _typeFilter).toList();
      }

      _sortDevices(mockList);
      _devices = mockList;
      _total = _devices.length;
      _lastFetchTime = DateTime.now();
      _isLoading = false;
      notifyListeners();
      return;
    }

    // ── Live mode ────────────────────────────────────────────────────────
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
      
      var liveList = rawDevices
          .whereType<Map<String, dynamic>>()
          .map(DeviceModel.fromJson)
          .toList();
          
      _sortDevices(liveList);
      _devices = liveList;
      _lastFetchTime = DateTime.now();
    } catch (e) {
      _errorMessage = 'Khong the tai danh sach thiet bi: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
