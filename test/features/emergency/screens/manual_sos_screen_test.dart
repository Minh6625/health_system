import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/emergency/screens/manual_sos_screen.dart';
import 'package:slide_to_act/slide_to_act.dart';

class _FakeEmergencyCaregiverRepository extends EmergencyCaregiverRepository {
  _FakeEmergencyCaregiverRepository({
    this.result = const TriggerSOSResult(sosId: 'sos-1', recipientCount: 2),
    this.triggerError,
  });

  final TriggerSOSResult result;
  final Object? triggerError;
  final List<Map<String, Object?>> triggerCalls = <Map<String, Object?>>[];

  @override
  Future<TriggerSOSResult> triggerSOS({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    triggerCalls.add({
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    });
    if (triggerError != null) {
      throw triggerError!;
    }
    return result;
  }
}

Widget _buildHarness(Widget child) {
  return MaterialApp(home: child);
}

bool _containsRichText(Widget widget, String expected) {
  return widget is RichText && widget.text.toPlainText().contains(expected);
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Position _position() {
  return Position(
    longitude: 106.456,
    latitude: 10.123,
    timestamp: DateTime(2026, 4, 20, 12),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  testWidgets(
    'auto countdown triggers SOS and shows confirm with backend count',
    (tester) async {
      final repository = _FakeEmergencyCaregiverRepository(
        result: const TriggerSOSResult(sosId: 'sos-77', recipientCount: 4),
      );
      var permissionRequested = false;

      await tester.pumpWidget(
        _buildHarness(
          ManualSOSScreen(
            repository: repository,
            initialCountdown: 1,
            countdownInterval: const Duration(milliseconds: 10),
            requestLocationPermission: () async {
              permissionRequested = true;
            },
            positionResolver: () async => null,
          ),
        ),
      );

      await tester.pump();
      expect(permissionRequested, isTrue);
      expect(
        find.byKey(const ValueKey('manual-sos-countdown')),
        findsOneWidget,
      );

      await _pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('sos-confirm-screen')),
      );

      expect(repository.triggerCalls, hasLength(1));
      expect(
        find.byWidgetPredicate(
          (widget) => _containsRichText(widget, 'Đã thông báo đến 4 người thân'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('slide submit sends immediately with injected location', (
    tester,
  ) async {
    final repository = _FakeEmergencyCaregiverRepository();

    await tester.pumpWidget(
      _buildHarness(
        ManualSOSScreen(
          repository: repository,
          initialCountdown: 30,
          countdownInterval: const Duration(seconds: 1),
          requestLocationPermission: () async {},
          positionResolver: () async => _position(),
        ),
      ),
    );

    await tester.pump();
    final slider = tester.widget<SlideAction>(
      find.byKey(const ValueKey('manual-sos-submit-slider')),
    );
    await slider.onSubmit!();
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey('sos-confirm-screen')),
    );

    expect(repository.triggerCalls, hasLength(1));
    expect(repository.triggerCalls.single['latitude'], 10.123);
    expect(repository.triggerCalls.single['longitude'], 106.456);
  });

  testWidgets('shows retry state when SOS request fails', (tester) async {
    final repository = _FakeEmergencyCaregiverRepository(
      triggerError: Exception('Network error'),
    );

    await tester.pumpWidget(
      _buildHarness(
        ManualSOSScreen(
          repository: repository,
          initialCountdown: 1,
          countdownInterval: const Duration(milliseconds: 10),
          requestLocationPermission: () async {},
          positionResolver: () async => null,
        ),
      ),
    );

    await tester.pump();
    await _pumpUntilVisible(
      tester,
      find.byKey(const ValueKey('manual-sos-network-error')),
    );

    expect(
      find.byKey(const ValueKey('manual-sos-submit-slider')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('manual-sos-sending-indicator')),
      findsNothing,
    );
  });
}
