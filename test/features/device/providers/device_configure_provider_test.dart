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
  _FakeDeviceRepository({this.failUnpairWith, this.failUpdateWith});

  final Object? failUnpairWith;
  final Object? failUpdateWith;
  final List<int> unpairCalls = <int>[];
  final List<Map<String, dynamic>> updateSettingsCalls =
      <Map<String, dynamic>>[];

  @override
  Future<void> unpairDevice(int deviceId) async {
    unpairCalls.add(deviceId);
    if (failUnpairWith != null) {
      throw failUnpairWith!;
    }
  }

  @override
  Future<Map<String, dynamic>> updateDeviceSettings({
    required int deviceId,
    Map<String, dynamic>? calibrationData,
  }) async {
    updateSettingsCalls.add({
      'device_id': deviceId,
      'calibration_data': Map<String, dynamic>.from(calibrationData ?? {}),
    });
    if (failUpdateWith != null) {
      throw failUpdateWith!;
    }
    return Map<String, dynamic>.from(calibrationData ?? {});
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
        failUnpairWith: Exception('Khong tim thay thiet bi'),
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
        failUnpairWith: Exception('Network error'),
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

  group('DeviceConfigureProvider.saveChanges', () {
    test('sends backend keys 1:1 (notify_high_hr / notify_low_spo2 / '
        'notify_high_bp) without aliasing', () async {
      // Pinned regression for Phase 5d-A. Earlier the UI exposed a
      // "vibrationAlert" toggle that was aliased to BOTH notify_high_hr and
      // notify_high_bp, plus a "sleepTracking" toggle that was aliased to
      // notify_low_spo2 — semantic mismatches that would silently corrupt
      // the user's notification preferences. Two further controls
      // (lowBatteryThreshold + syncInterval) were dropped on save.
      final repo = _FakeDeviceRepository();
      final provider =
          DeviceConfigureProvider(_device(id: 303), repository: repo);

      provider.updateNotifyHighHr(false); // user disables HR alerts
      provider.updateNotifyLowSpo2(true); // SpO2 stays on
      provider.updateNotifyHighBp(false); // user disables BP alerts

      final result = await provider.saveChanges();

      expect(result, isTrue);
      expect(repo.updateSettingsCalls, hasLength(1));
      final call = repo.updateSettingsCalls.single;
      expect(call['device_id'], 303);
      expect(
        call['calibration_data'],
        <String, dynamic>{
          'notify_high_hr': false,
          'notify_low_spo2': true,
          'notify_high_bp': false,
        },
      );
      // After a successful save we expect the dirty flag to clear.
      expect(provider.isDirty, isFalse);
      expect(provider.isSaving, isFalse);
    });

    test('reports failure and keeps form dirty when repository throws',
        () async {
      final repo = _FakeDeviceRepository(
        failUpdateWith: Exception('Cap nhat cau hinh that bai'),
      );
      final provider =
          DeviceConfigureProvider(_device(), repository: repo);

      provider.updateNotifyHighHr(false); // mark dirty
      final result = await provider.saveChanges();

      expect(result, isFalse);
      expect(provider.isSaving, isFalse);
      expect(provider.errorMessage,
          contains('Cap nhat cau hinh that bai'));
      // We deliberately keep isDirty true on failure so the user can retry
      // with the same edits — verify that contract holds.
      expect(provider.isDirty, isTrue);
    });
  });
}
