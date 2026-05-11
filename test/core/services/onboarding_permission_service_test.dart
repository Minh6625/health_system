import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:healthguard/core/services/onboarding_permission_service.dart';

/// F-15 (P-3) regression tests for [OnboardingPermissionService].
///
/// The service gates a one-time location-permission primer on three
/// independent signals:
///   1. Has the user seen the primer before? (secure storage flag)
///   2. What is the current OS permission state?
///   3. Did either lookup throw?
///
/// These tests pin the truth table so the gating logic doesn't drift
/// silently — the wrong answer means either nagging the user every
/// cold start (false positive) or hiding the primer when it should
/// be shown (false negative, defeats the purpose of the fix).
class _InMemorySecureStorage implements FlutterSecureStorage {
  _InMemorySecureStorage({this.failOnRead = false, this.failOnWrite = false});

  final Map<String, String> store = <String, String>{};
  bool failOnRead;
  bool failOnWrite;

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

  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Method ${invocation.memberName} not stubbed in this test',
    );
  }
}

void main() {
  group('OnboardingPermissionService.shouldShowLocationPrimer — F-15 (P-3)',
      () {
    test(
        'returns true when user has never seen primer AND OS permission '
        'is denied (the one state where a request would actually surface '
        'a dialog) — this is the canonical "show it" case', () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => LocationPermission.denied,
      );

      expect(await service.shouldShowLocationPrimer(), isTrue);
    });

    test(
        'returns false when user has seen primer before — never re-prompts '
        'on the same install (key signal: tester complaint was being '
        'asked every SOS, fix must not become "asked every cold start")',
        () async {
      final storage = _InMemorySecureStorage();
      storage.store[OnboardingPermissionService.storageKey] = 'true';
      final service = OnboardingPermissionService(
        storage: storage,
        checkPermission: () async => LocationPermission.denied,
      );

      expect(await service.shouldShowLocationPrimer(), isFalse);
    });

    test(
        'returns false when OS already granted whileInUse — no point '
        'educating about a setting that is already on', () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => LocationPermission.whileInUse,
      );

      expect(await service.shouldShowLocationPrimer(), isFalse);
    });

    test(
        'returns false when OS already granted always — no point '
        'educating about a setting that is already on', () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => LocationPermission.always,
      );

      expect(await service.shouldShowLocationPrimer(), isFalse);
    });

    test(
        'returns false when OS deniedForever — only Settings can fix this, '
        'an in-app primer would be a dead-end and just frustrate the user',
        () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => LocationPermission.deniedForever,
      );

      expect(await service.shouldShowLocationPrimer(), isFalse);
    });

    test(
        'returns false when storage read throws — be conservative; '
        'better to skip an educational nudge than to show it on every '
        'cold start because storage is flaky', () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(failOnRead: true),
        checkPermission: () async => LocationPermission.denied,
      );

      expect(await service.shouldShowLocationPrimer(), isFalse);
    });

    test(
        'returns false when permission check throws — protects against '
        'Android emulators with a missing Google Play Services binding '
        '(a known Geolocator failure mode that should not crash the '
        'dashboard)', () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => throw StateError('GMS missing'),
      );

      expect(await service.shouldShowLocationPrimer(), isFalse);
    });
  });

  group('OnboardingPermissionService.markLocationPrimerShown — F-15 (P-3)',
      () {
    test('writes "true" to the storage key so subsequent gating returns false',
        () async {
      final storage = _InMemorySecureStorage();
      final service = OnboardingPermissionService(
        storage: storage,
        checkPermission: () async => LocationPermission.denied,
      );

      // Before mark: gate is open.
      expect(await service.shouldShowLocationPrimer(), isTrue);

      await service.markLocationPrimerShown();

      // After mark: gate is closed regardless of OS permission state.
      expect(storage.store[OnboardingPermissionService.storageKey], 'true');
      expect(await service.shouldShowLocationPrimer(), isFalse);
    });

    test(
        'tolerates write failure (does not throw) — the user-visible '
        'primer has already closed at this point, so a thrown exception '
        'would be useless noise', () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(failOnWrite: true),
        checkPermission: () async => LocationPermission.denied,
      );

      // Must NOT throw.
      await service.markLocationPrimerShown();
    });
  });

  group('OnboardingPermissionService.requestLocationPermission — F-15 (P-3)',
      () {
    test('returns whatever the OS prompt resolves to (granted path)',
        () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        requestPermission: () async => LocationPermission.whileInUse,
      );

      final result = await service.requestLocationPermission();

      expect(result, LocationPermission.whileInUse);
    });

    test('returns whatever the OS prompt resolves to (denied path)',
        () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        requestPermission: () async => LocationPermission.denied,
      );

      final result = await service.requestLocationPermission();

      expect(result, LocationPermission.denied);
    });

    test(
        'soft-fails to denied when the request throws — a primer tap must '
        'never crash the dashboard regardless of platform plugin state',
        () async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        requestPermission: () async => throw StateError('plugin not bound'),
      );

      final result = await service.requestLocationPermission();

      expect(result, LocationPermission.denied);
    });
  });
}
