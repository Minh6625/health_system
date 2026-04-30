import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:healthguard/core/services/onboarding_permission_service.dart';
import 'package:healthguard/features/onboarding/widgets/location_permission_primer_sheet.dart';

/// F-15 (P-3) widget tests for [LocationPermissionPrimerSheet] +
/// [showLocationPermissionPrimer].
///
/// These tests cover the user-facing guarantees that the unit tests
/// for the service alone cannot verify:
///
///   1. Primer renders the expected Vietnamese copy + both CTAs.
///   2. "Cho phép" tap triggers `requestLocationPermission` AND marks
///      the primer as shown (so it never reappears).
///   3. "Để sau" tap marks the primer as shown WITHOUT firing the
///      OS request (App Store guideline 5.1.1: no permission
///      prompt without explicit user opt-in).
///   4. `showLocationPermissionPrimer` is a no-op when
///      `shouldShowLocationPrimer` returns false (e.g. user already
///      saw it on a previous launch).
class _InMemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      store[key];

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
  group('LocationPermissionPrimerSheet — F-15 (P-3)', () {
    testWidgets('renders Vietnamese title + body + both CTAs', (tester) async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.whileInUse,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LocationPermissionPrimerSheet(service: service),
        ),
      ));

      expect(find.text('Bật vị trí để gửi SOS nhanh hơn'), findsOneWidget);
      // Body text — partial match because the full string contains
      // line breaks + soft-wrap whitespace that flutter_test
      // collapses inconsistently across platforms.
      expect(
        find.textContaining('chia sẻ ngay với người thân'),
        findsOneWidget,
      );
      expect(find.text('Cho phép'), findsOneWidget);
      expect(find.text('Để sau'), findsOneWidget);
    });

    testWidgets(
        'tapping "Cho phép" fires requestLocationPermission, marks the '
        'primer as shown, and pops the sheet — the canonical happy path',
        (tester) async {
      final storage = _InMemorySecureStorage();
      var requestCalls = 0;
      final service = OnboardingPermissionService(
        storage: storage,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.whileInUse;
        },
      );

      LocationPermission? receivedResult;
      var resultCallbackInvocations = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => LocationPermissionPrimerSheet(
                    service: service,
                    onResult: (result) {
                      receivedResult = result;
                      resultCallbackInvocations++;
                    },
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Cho phép'), findsOneWidget);

      await tester.tap(find.text('Cho phép'));
      await tester.pumpAndSettle();

      expect(requestCalls, 1, reason: 'Geolocator request must be invoked');
      expect(
        storage.store[OnboardingPermissionService.storageKey],
        'true',
        reason: 'Persistence flag must flip after a "Cho phép" tap',
      );
      expect(
        receivedResult,
        LocationPermission.whileInUse,
        reason: 'onResult must receive the OS-level permission outcome',
      );
      expect(resultCallbackInvocations, 1);
      expect(find.text('Cho phép'), findsNothing,
          reason: 'Sheet must close after the tap');
    });

    testWidgets(
        'tapping "Để sau" marks the primer as shown WITHOUT firing the '
        'OS request — App Store 5.1.1 compliance: no permission prompt '
        'without explicit user opt-in', (tester) async {
      final storage = _InMemorySecureStorage();
      var requestCalls = 0;
      final service = OnboardingPermissionService(
        storage: storage,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.whileInUse;
        },
      );

      LocationPermission? receivedResult = LocationPermission.unableToDetermine;
      var resultCallbackInvocations = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => LocationPermissionPrimerSheet(
                    service: service,
                    onResult: (result) {
                      receivedResult = result;
                      resultCallbackInvocations++;
                    },
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(requestCalls, 0,
          reason:
              'Geolocator request must NOT fire for the deferred path');
      expect(
        storage.store[OnboardingPermissionService.storageKey],
        'true',
        reason:
            'Persistence flag must still flip — primer is one-shot, not '
            'one-shot-conditional-on-tap',
      );
      expect(receivedResult, isNull,
          reason: '"Để sau" surfaces null in onResult to signal '
              '"no permission decision happened"');
      expect(resultCallbackInvocations, 1);
    });
  });

  group('showLocationPermissionPrimer — F-15 (P-3) helper', () {
    testWidgets(
        'returns false and shows nothing when shouldShowLocationPrimer '
        'is false — gating already saved the user from a redundant '
        'nudge upstream', (tester) async {
      final storage = _InMemorySecureStorage();
      // Pre-populate the "already shown" flag so the gate is closed.
      storage.store[OnboardingPermissionService.storageKey] = 'true';

      final service = OnboardingPermissionService(
        storage: storage,
        checkPermission: () async => LocationPermission.denied,
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          capturedContext = context;
          return const Scaffold(body: SizedBox.shrink());
        }),
      ));

      final shown = await showLocationPermissionPrimer(
        context: capturedContext,
        service: service,
      );

      expect(shown, isFalse);
      expect(find.text('Bật vị trí để gửi SOS nhanh hơn'), findsNothing);
    });

    testWidgets(
        'returns true and shows the sheet when the gate is open — '
        'verifies the wiring between the service gate and the actual '
        'modal-bottom-sheet plumbing', (tester) async {
      final service = OnboardingPermissionService(
        storage: _InMemorySecureStorage(),
        checkPermission: () async => LocationPermission.denied,
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          capturedContext = context;
          return const Scaffold(body: SizedBox.shrink());
        }),
      ));

      // Fire-and-forget — the helper await-s on showModalBottomSheet
      // which only resolves when the sheet pops. We pump once to
      // surface the sheet, assert, then dismiss.
      final future = showLocationPermissionPrimer(
        context: capturedContext,
        service: service,
      );
      await tester.pumpAndSettle();

      expect(find.text('Bật vị trí để gửi SOS nhanh hơn'), findsOneWidget);

      // Dismiss via the deferred path so the future resolves.
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(await future, isTrue);
    });
  });
}
