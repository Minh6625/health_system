import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/features/profile/providers/clinician_audience_provider.dart';

/// In-memory mock of [FlutterSecureStorage] so we don't need the
/// platform channels in unit tests.
class _InMemorySecureStorage implements FlutterSecureStorage {
  _InMemorySecureStorage({this.failOnWrite = false, this.failOnRead = false});

  final Map<String, String> store = <String, String>{};
  bool failOnWrite;
  bool failOnRead;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failOnRead) throw StateError('simulated read failure');
    return store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failOnWrite) throw StateError('simulated write failure');
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  // Unused stubs.
  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Method ${invocation.memberName} not stubbed in this test',
    );
  }
}

void main() {
  group('ClinicianAudienceProvider', () {
    test('initial state is enabled=false + isInitialized=false', () {
      final provider = ClinicianAudienceProvider(
        storage: _InMemorySecureStorage(),
      );
      expect(provider.enabled, isFalse);
      expect(provider.isInitialized, isFalse);
      expect(provider.audienceQueryValue, isNull);
    });

    test('init() with no stored value defaults to enabled=false', () async {
      final storage = _InMemorySecureStorage();
      final provider = ClinicianAudienceProvider(storage: storage);

      await provider.init();

      expect(provider.isInitialized, isTrue);
      expect(provider.enabled, isFalse);
    });

    test('init() with stored "true" hydrates enabled=true', () async {
      final storage = _InMemorySecureStorage();
      storage.store[ClinicianAudienceProvider.storageKey] = 'true';
      final provider = ClinicianAudienceProvider(storage: storage);

      await provider.init();

      expect(provider.enabled, isTrue);
      expect(provider.audienceQueryValue, 'clinician');
    });

    test('init() with stored "false" hydrates enabled=false', () async {
      final storage = _InMemorySecureStorage();
      storage.store[ClinicianAudienceProvider.storageKey] = 'false';
      final provider = ClinicianAudienceProvider(storage: storage);

      await provider.init();

      expect(provider.enabled, isFalse);
    });

    test('init() with malformed stored value falls back to enabled=false',
        () async {
      // Defensive: corrupted disk state must NOT leak clinical content.
      final storage = _InMemorySecureStorage();
      storage.store[ClinicianAudienceProvider.storageKey] = 'mostly true';
      final provider = ClinicianAudienceProvider(storage: storage);

      await provider.init();

      expect(provider.enabled, isFalse);
    });

    test('init() that throws does not propagate; stays enabled=false',
        () async {
      final provider = ClinicianAudienceProvider(
        storage: _InMemorySecureStorage(failOnRead: true),
      );

      await provider.init();

      // Soft-fail closed: a busted storage layer leaves the user in
      // patient mode rather than blowing up the app.
      expect(provider.isInitialized, isTrue);
      expect(provider.enabled, isFalse);
    });

    test('init() is idempotent: a second call is a no-op', () async {
      final storage = _InMemorySecureStorage();
      final provider = ClinicianAudienceProvider(storage: storage);
      await provider.init();
      // Mutate storage AFTER init — a second init() must NOT pick this up.
      storage.store[ClinicianAudienceProvider.storageKey] = 'true';

      await provider.init();

      expect(provider.enabled, isFalse);
    });

    test('setEnabled(true) updates state + persists to storage', () async {
      final storage = _InMemorySecureStorage();
      final provider = ClinicianAudienceProvider(storage: storage);
      await provider.init();
      expect(provider.enabled, isFalse);

      await provider.setEnabled(true);

      expect(provider.enabled, isTrue);
      expect(provider.isInitialized, isTrue);
      expect(provider.audienceQueryValue, 'clinician');
      expect(
        storage.store[ClinicianAudienceProvider.storageKey],
        'true',
      );
    });

    test('setEnabled(false) clears the stored "true" flag', () async {
      final storage = _InMemorySecureStorage();
      storage.store[ClinicianAudienceProvider.storageKey] = 'true';
      final provider = ClinicianAudienceProvider(storage: storage);
      await provider.init();
      expect(provider.enabled, isTrue);

      await provider.setEnabled(false);

      expect(provider.enabled, isFalse);
      expect(provider.audienceQueryValue, isNull);
      expect(
        storage.store[ClinicianAudienceProvider.storageKey],
        'false',
      );
    });

    test('setEnabled is idempotent for the same value (and isInitialized)',
        () async {
      final storage = _InMemorySecureStorage();
      final provider = ClinicianAudienceProvider(storage: storage);
      await provider.init();

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setEnabled(false);  // already false
      expect(notifyCount, 0);

      await provider.setEnabled(true);
      expect(notifyCount, 1);

      await provider.setEnabled(true);  // already true
      expect(notifyCount, 1);
    });

    test('setEnabled tolerates a write failure: in-memory still flips',
        () async {
      final storage = _InMemorySecureStorage(failOnWrite: true);
      final provider = ClinicianAudienceProvider(storage: storage);
      await provider.init();

      // Must NOT throw — UI must reflect the user's tap immediately.
      await provider.setEnabled(true);

      expect(provider.enabled, isTrue);
      // Storage is empty because the simulated write failed; that's
      // fine — the next app start regresses to the persisted (default
      // false) state, which is the safe direction.
      expect(
        storage.store.containsKey(ClinicianAudienceProvider.storageKey),
        isFalse,
      );
    });

    test('audienceQueryValue toggles between null and "clinician"', () async {
      final provider = ClinicianAudienceProvider(
        storage: _InMemorySecureStorage(),
      );
      await provider.init();

      expect(provider.audienceQueryValue, isNull);
      await provider.setEnabled(true);
      expect(provider.audienceQueryValue, 'clinician');
      await provider.setEnabled(false);
      expect(provider.audienceQueryValue, isNull);
    });
  });
}
