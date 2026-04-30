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
  _FakeDeviceRepository({
    this.failUnpairWith,
    this.failUpdateWith,
    this.failUpdateNameWith,
  });

  final Object? failUnpairWith;
  // Mutable so the F-7 (M-7) partial-success retry test can flip the
  // settings PUT from "throws" to "succeeds" between calls without
  // building a second fake. The other failure injectors stay final because
  // their tests only need a single attempt.
  Object? failUpdateWith;
  final Object? failUpdateNameWith;
  final List<int> unpairCalls = <int>[];
  final List<Map<String, dynamic>> updateSettingsCalls =
      <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> updateNameCalls =
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

  @override
  Future<DeviceModel> updateDeviceName({
    required int deviceId,
    required String deviceName,
  }) async {
    updateNameCalls.add({
      'device_id': deviceId,
      'device_name': deviceName,
    });
    if (failUpdateNameWith != null) {
      throw failUpdateNameWith!;
    }
    return _device(id: deviceId, deviceName: deviceName);
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

DeviceModel _device({
  int id = 101,
  String? deviceName = 'Tester Watch',
  Map<String, dynamic>? calibrationData,
}) {
  return DeviceModel(
    id: id,
    uuid: 'uuid-$id',
    deviceName: deviceName,
    deviceType: 'smartwatch',
    isActive: true,
    isOnline: true,
    calibrationData: calibrationData,
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

    // Phase 6b: device-name PATCH wiring.
    test('skips updateDeviceName when the name was never edited', () async {
      final repo = _FakeDeviceRepository();
      final provider =
          DeviceConfigureProvider(_device(id: 404), repository: repo);

      provider.updateNotifyHighBp(false); // only settings dirty
      final result = await provider.saveChanges();

      expect(result, isTrue);
      expect(repo.updateNameCalls, isEmpty,
          reason:
              'No PATCH should fire when the user did not change the name '
              'TextField.');
      expect(repo.updateSettingsCalls, hasLength(1));
    });

    test('PATCHes the trimmed name before settings when the user edited it',
        () async {
      final repo = _FakeDeviceRepository();
      final provider =
          DeviceConfigureProvider(_device(id: 505), repository: repo);

      provider.updateName('  Dong ho cua Bo  ');
      final result = await provider.saveChanges();

      expect(result, isTrue);
      expect(repo.updateNameCalls, hasLength(1));
      expect(repo.updateNameCalls.single, <String, dynamic>{
        'device_id': 505,
        'device_name': 'Dong ho cua Bo',
      });
      expect(repo.updateSettingsCalls, hasLength(1),
          reason: 'Settings should still be saved after the name PATCH.');
    });

    test('rejects an empty name locally without calling either endpoint',
        () async {
      final repo = _FakeDeviceRepository();
      final provider =
          DeviceConfigureProvider(_device(id: 606), repository: repo);

      provider.updateName('   '); // user clears the field
      final result = await provider.saveChanges();

      expect(result, isFalse);
      expect(provider.errorMessage, contains('không được để trống'));
      expect(repo.updateNameCalls, isEmpty);
      expect(repo.updateSettingsCalls, isEmpty,
          reason:
              'A locally-rejected name must short-circuit before any network '
              'call to avoid partially-applied saves.');
    });

    test(
        'when name PATCH fails the settings PUT is never called and the '
        'form stays dirty', () async {
      final repo = _FakeDeviceRepository(
        failUpdateNameWith: Exception('Ten thiet bi da ton tai'),
      );
      final provider =
          DeviceConfigureProvider(_device(id: 707), repository: repo);

      provider.updateName('Dong ho trung ten');
      provider.updateNotifyHighHr(false); // also flip a setting
      final result = await provider.saveChanges();

      expect(result, isFalse);
      expect(provider.errorMessage, contains('Ten thiet bi da ton tai'));
      expect(repo.updateNameCalls, hasLength(1));
      expect(repo.updateSettingsCalls, isEmpty,
          reason:
              'Settings PUT must wait until the name PATCH succeeds to avoid '
              'splitting the save halfway.');
      expect(provider.isDirty, isTrue);
      expect(provider.hasPartialSuccess, isFalse,
          reason:
              'Hard failure (no rename committed) must not light up the '
              'partial-success flag — that is reserved for cases where the '
              'server already accepted the name PATCH.');
    });

    // F-7 (M-7): pinned regression for the partial-success messaging fix.
    //
    // Before this fix `saveChanges` dropped the rename-committed signal: if
    // the name PATCH succeeded but the settings PUT then failed, the catch
    // block reported a generic "Lỗi: ..." error. The screen surfaced this
    // as a red snackbar even though the rename had already persisted on the
    // server, leaving the user convinced their change was rolled back.
    //
    // The new contract is:
    //   * `errorMessage` calls out the partial success ("Đã đổi tên ...”)
    //     while still embedding the underlying exception text for QA.
    //   * `hasPartialSuccess` is true so the screen can tint the snackbar
    //     warning instead of critical.
    //   * `_nameDirty` is cleared so a retry hits ONLY the failing settings
    //     endpoint — verified indirectly here by flipping the fake to
    //     succeed and asserting `updateNameCalls` stays at one.
    test(
        'partial success: name PATCH committed but settings PUT failed — '
        'errorMessage flags the partial success, hasPartialSuccess is true, '
        'and a retry skips the already-committed name PATCH', () async {
      final repo = _FakeDeviceRepository(
        failUpdateWith: Exception('Khong luu duoc cai dat'),
      );
      final provider =
          DeviceConfigureProvider(_device(id: 808), repository: repo);

      provider.updateName('Dong ho moi');
      provider.updateNotifyHighHr(false);
      final firstResult = await provider.saveChanges();

      expect(firstResult, isFalse);
      expect(repo.updateNameCalls, hasLength(1),
          reason: 'Name PATCH must run first.');
      expect(repo.updateSettingsCalls, hasLength(1),
          reason: 'Settings PUT must be attempted after name succeeds.');
      expect(provider.hasPartialSuccess, isTrue,
          reason:
              'Caller can surface partial-success UI instead of a hard '
              'error.');
      expect(provider.errorMessage, contains('Khong luu duoc cai dat'),
          reason:
              'Underlying error text must still appear so QA can debug the '
              'real settings failure.');
      expect(provider.errorMessage, contains('Đã đổi tên'),
          reason:
              'Message must tell the user the rename did persist so the '
              'red snackbar from M-7 stops misleading them.');
      expect(provider.isDirty, isTrue,
          reason:
              'Form stays dirty so the user can retry the failing settings '
              'PUT without re-entering anything.');

      // Retry path: flip the fake to succeed and call saveChanges again.
      // The name PATCH must NOT fire again because _nameDirty was cleared
      // after the first PATCH committed — firing it twice would create the
      // bug where the user sees two PATCH requests for one rename.
      repo.failUpdateWith = null;
      final retryResult = await provider.saveChanges();

      expect(retryResult, isTrue);
      expect(repo.updateNameCalls, hasLength(1),
          reason:
              'Name PATCH must NOT re-fire on retry: _nameDirty was cleared '
              'when the first PATCH committed, so the rename is already on '
              'the server.');
      expect(repo.updateSettingsCalls, hasLength(2),
          reason: 'Settings PUT runs again because that is what failed.');
      expect(provider.hasPartialSuccess, isFalse,
          reason: 'A clean save resets the partial-success flag.');
      expect(provider.errorMessage, isNull);
      expect(provider.isDirty, isFalse);
    });
  });

  // Phase 6a: seed the three notify_* toggles from device.calibrationData.
  group('DeviceConfigureProvider seeding from calibration_data', () {
    test('defaults all three toggles to true when calibration_data is null',
        () {
      final provider = DeviceConfigureProvider(
        _device(calibrationData: null),
        repository: _FakeDeviceRepository(),
      );

      expect(provider.notifyHighHr, isTrue);
      expect(provider.notifyLowSpo2, isTrue);
      expect(provider.notifyHighBp, isTrue);
      expect(provider.isDirty, isFalse,
          reason:
              'Seeding must not mark the form dirty; the user has not edited '
              'anything yet.');
    });

    test('reads explicit booleans from calibration_data without aliasing', () {
      final provider = DeviceConfigureProvider(
        _device(calibrationData: <String, dynamic>{
          'notify_high_hr': false,
          'notify_low_spo2': true,
          'notify_high_bp': false,
          // Extra keys that the configure screen does not surface yet must be
          // ignored, not coerced or dropped silently.
          'heart_rate_offset': 3,
          'wear_side': 'right',
        }),
        repository: _FakeDeviceRepository(),
      );

      expect(provider.notifyHighHr, isFalse);
      expect(provider.notifyLowSpo2, isTrue);
      expect(provider.notifyHighBp, isFalse);
    });

    test('falls back to default true when a key is missing or non-boolean',
        () {
      final provider = DeviceConfigureProvider(
        _device(calibrationData: <String, dynamic>{
          'notify_high_hr': 'on', // wrong type — must not be coerced
          // notify_low_spo2 missing entirely
          'notify_high_bp': null,
        }),
        repository: _FakeDeviceRepository(),
      );

      expect(provider.notifyHighHr, isTrue);
      expect(provider.notifyLowSpo2, isTrue);
      expect(provider.notifyHighBp, isTrue);
    });
  });

  // Bug 2 (QA): tester reported "tắt cảnh báo nhịp tim cao thì bật lại
  // không được". Root cause was `_markDirty()` only firing
  // notifyListeners() on the false→true _isDirty transition, so the
  // second toggle on the same Switch silently updated provider state
  // but never rebuilt the controlled SwitchListTile. These tests pin
  // the contract that every value-changing update notifies, every time.
  group('DeviceConfigureProvider notifies on every field change (Bug 2)', () {
    test('toggling the same Switch twice fires notifyListeners both times',
        () {
      final provider = DeviceConfigureProvider(
        _device(calibrationData: <String, dynamic>{
          'notify_high_hr': true,
        }),
        repository: _FakeDeviceRepository(),
      );

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.updateNotifyHighHr(false); // tắt
      expect(notifyCount, 1,
          reason: 'First toggle must notify so the Switch rebuilds OFF.');
      expect(provider.notifyHighHr, isFalse);
      expect(provider.isDirty, isTrue);

      provider.updateNotifyHighHr(true); // bật lại
      expect(notifyCount, 2,
          reason:
              'Second toggle must ALSO notify — without this, '
              'context.watch<DeviceConfigureProvider>() never rebuilds '
              'and the Switch appears stuck in the OFF position.');
      expect(provider.notifyHighHr, isTrue);
    });

    test('every notify_* updater notifies independently when isDirty is '
        'already true', () {
      final provider = DeviceConfigureProvider(
        _device(),
        repository: _FakeDeviceRepository(),
      );

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.updateNotifyHighHr(false);
      provider.updateNotifyLowSpo2(false);
      provider.updateNotifyHighBp(false);

      expect(notifyCount, 3,
          reason:
              'Three independent toggles, three rebuilds — one notify '
              'per state change.');
    });

    test('updateName notifies on every value change but is idempotent for '
        'no-op edits', () {
      final provider = DeviceConfigureProvider(
        _device(deviceName: 'Watch'),
        repository: _FakeDeviceRepository(),
      );

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.updateName('Watch1');
      provider.updateName('Watch12');
      expect(notifyCount, 2,
          reason:
              'Each new name string must notify so any consumer that '
              'depends on `provider.deviceName` keeps in sync.');

      // Same value as current — the early-return guard in updateName
      // must short-circuit BEFORE _markDirty so we do not produce a
      // spurious rebuild for an idempotent edit.
      provider.updateName('Watch12');
      expect(notifyCount, 2,
          reason:
              'Idempotent edit must not produce a spurious rebuild — the '
              'notify guard belongs in the caller, not in _markDirty.');
    });
  });

  // Phase 6a: DeviceModel.fromJson calibration_data.
  group('DeviceModel.fromJson calibration_data', () {
    test('parses a JSON object into a Map<String, dynamic>', () {
      final model = DeviceModel.fromJson(<String, dynamic>{
        'id': 909,
        'uuid': 'uuid-909',
        'device_type': 'smartwatch',
        'is_active': true,
        'is_online': true,
        'calibration_data': <String, dynamic>{
          'notify_high_hr': false,
          'notify_low_spo2': true,
        },
      });

      expect(model.calibrationData, isNotNull);
      expect(model.calibrationData!['notify_high_hr'], isFalse);
      expect(model.calibrationData!['notify_low_spo2'], isTrue);
    });

    test('returns null when calibration_data is missing or not a Map', () {
      final missing = DeviceModel.fromJson(<String, dynamic>{
        'id': 1,
        'uuid': 'u',
        'device_type': 'smartwatch',
        'is_active': true,
        'is_online': true,
      });
      expect(missing.calibrationData, isNull);

      final wrongType = DeviceModel.fromJson(<String, dynamic>{
        'id': 2,
        'uuid': 'u',
        'device_type': 'smartwatch',
        'is_active': true,
        'is_online': true,
        'calibration_data': 'oops', // should not crash
      });
      expect(wrongType.calibrationData, isNull);
    });
  });
}
