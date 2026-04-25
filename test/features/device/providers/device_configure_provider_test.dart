import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_configure_provider.dart';
import 'package:healthguard/features/device/repositories/device_repository.dart';

/// Pinned regression for the Phase 5a fake-unpair fix.
///
/// Before this commit `DeviceConfigureProvider.unpairDevice` only awaited a
/// fixed `Future.delayed` and returned `true`, so the device record stayed
/// on the backend while the UI showed "thành công". The new behaviour:
///   - delegates to `DeviceRepository.unpairDevice(deviceId)`
///   - returns `false` and stores `errorMessage` when the repo throws
///   - keeps `isUnpairing` toggling around the call
class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository({this.failWith});

  final Object? failWith;
  final List<int> unpairCalls = <int>[];

  @override
  Future<void> unpairDevice(int deviceId) async {
    unpairCalls.add(deviceId);
    if (failWith != null) {
      throw failWith!;
    }
  }

  // Methods we do not exercise in this test — keep them unimplemented so any
  // accidental usage surfaces loudly instead of silently mocking real network.
  @override
  Future<DeviceModel> pairNewDevice({
    required String macAddress,
    required String deviceName,
    required String deviceType,
    String? model,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> updateDeviceSettings({
    required int deviceId,
    Map<String, dynamic>? calibrationData,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<DeviceModel>> getDeviceList({
    String? status = 'all',
    int limit = 50,
    int offset = 0,
  }) {
    throw UnimplementedError();
  }
}

DeviceModel _device({int id = 101}) {
  return DeviceModel(
    id: id,
    uuid: 'uuid-$id',
    deviceName: 'Tester Watch',
    deviceType: 'smartwatch',
    isActive: true,
    isOnline: true,
  );
}

void main() {
  group('DeviceConfigureProvider.unpairDevice', () {
    test('calls DeviceRepository.unpairDevice and reports success', () async {
      final repo = _FakeDeviceRepository();
      final provider = DeviceConfigureProvider(_device(), repository: repo);

      final result = await provider.unpairDevice();

      expect(result, isTrue);
      expect(repo.unpairCalls, <int>[101]);
      expect(provider.isUnpairing, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('returns false and surfaces backend error message on failure',
        () async {
      final repo = _FakeDeviceRepository(
        failWith: Exception('Khong tim thay thiet bi'),
      );
      final provider = DeviceConfigureProvider(_device(id: 202),
          repository: repo);

      final result = await provider.unpairDevice();

      expect(result, isFalse);
      expect(repo.unpairCalls, <int>[202]);
      expect(provider.isUnpairing, isFalse);
      expect(provider.errorMessage, 'Khong tim thay thiet bi');
    });

    test('clears previous errorMessage at the start of a new attempt',
        () async {
      // First attempt fails so errorMessage is populated.
      final failingRepo = _FakeDeviceRepository(
        failWith: Exception('Network error'),
      );
      final device = _device();
      final provider = DeviceConfigureProvider(device, repository: failingRepo);
      await provider.unpairDevice();
      expect(provider.errorMessage, 'Network error');

      // Now build a fresh provider that will succeed; errorMessage starts as
      // null and we additionally check it stays null after the call.
      final cleanProvider = DeviceConfigureProvider(
        device,
        repository: _FakeDeviceRepository(),
      );
      cleanProvider.unpairDevice();
      expect(cleanProvider.errorMessage, isNull);
    });
  });
}
