/// Widget tests for [FallStandUpSurveyScreen] (Module FA-2 — Option
/// 3-Lite).
///
/// We use the same fake-repository + fake-provider pattern as
/// ``fall_event_provider_test.dart`` so the screen can be pumped
/// without an `ApiClient` / network. Each test exercises one of the
/// four paths the survey screen can take:
///
///   1. Tap "Có, tôi đứng dậy được"  → submitSurvey(canStand=true,  skipped=false)
///   2. Tap "Không, cần ai đó giúp" → submitSurvey(canStand=false, skipped=false)
///   3. Tap "Bỏ qua"                → submitSurvey(canStand=null,  skipped=true)
///   4. Timer expires (no tap)      → same as "Bỏ qua"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/providers/fall_event_provider.dart';
import 'package:healthguard/features/fall/repositories/fall_event_repository.dart';
import 'package:healthguard/features/fall/screens/fall_stand_up_survey_screen.dart';

class _CapturingRepository implements FallEventRepository {
  int submitCalls = 0;
  bool? lastCanStand;
  bool? lastSkipped;

  @override
  Future<FallEventList> listEvents({
    int limit = 20,
    int offset = 0,
    String? patientId,
  }) async => FallEventList(items: const [], total: 0, limit: limit, offset: offset);

  @override
  Future<FallEvent?> getEvent(int id, {String? patientId}) async => null;

  @override
  Future<FallEvent?> dismiss(int id, {String? reason, String? patientId}) async => null;

  @override
  Future<FallEvent?> submitSurvey(
    int id, {
    required bool? canStand,
    required bool skipped,
    String? patientId,
  }) async {
    submitCalls++;
    lastCanStand = canStand;
    lastSkipped = skipped;
    return _stubEvent(id: id, surveyAnswers: {
      'can_stand': canStand,
      'skipped': skipped,
      'answered_at': DateTime(2026, 5, 1).toIso8601String(),
    });
  }
}

FallEvent _stubEvent({
  int id = 17,
  Map<String, dynamic>? surveyAnswers,
}) {
  return FallEvent(
    id: id,
    uuid: 'u-$id',
    deviceId: 5,
    detectedAt: DateTime(2026, 5, 1),
    confidence: 0.91,
    status: FallEventStatus.dismissed,
    userCancelled: true,
    cancelReason: 'Tôi ổn',
    surveyAnswers: surveyAnswers,
  );
}

Widget _wrap({
  required _CapturingRepository repo,
  required FallEvent event,
  required void Function() onClose,
  Duration? testCountdownOverride,
}) {
  // Wrap with MaterialApp so Theme + ScaffoldMessenger work, then
  // hand the screen an explicit onClose callback so it does NOT call
  // ``Navigator.pop`` — the test root has no parent route, and the
  // FallCountdownRing's periodic Timer keeps pumpAndSettle hung
  // otherwise.
  return MaterialApp(
    home: ChangeNotifierProvider<FallEventProvider>(
      create: (_) => FallEventProvider(repository: repo),
      child: FallStandUpSurveyScreen(
        event: event,
        testCountdownOverride: testCountdownOverride,
        onClose: onClose,
      ),
    ),
  );
}

void main() {
  // The survey screen renders a tall column (header + countdown ring +
  // three 80-dp buttons + disclaimer); the default 800×600 test
  // viewport overflows.  Use a phone-sized viewport so the Column
  // fits comfortably.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.physicalSizeTestValue = const Size(1080, 2400);
    binding.window.devicePixelRatioTestValue = 3.0;
  });
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  group('FallStandUpSurveyScreen', () {
    testWidgets('renders three buttons + timer ring', (tester) async {
      final repo = _CapturingRepository();
      var closed = false;
      await tester.pumpWidget(_wrap(
        repo: repo,
        event: _stubEvent(),
        onClose: () => closed = true,
        // Long countdown so the auto-skip doesn't fire during pump.
        testCountdownOverride: const Duration(seconds: 30),
      ));

      expect(find.text('Bạn có thể đứng dậy được không?'), findsOneWidget);
      expect(find.text('Có, tôi đứng dậy được'), findsOneWidget);
      expect(find.text('Không, cần ai đó giúp'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(closed, isFalse, reason: 'No tap yet → onClose must not fire');
    });

    testWidgets('tap "Có" → submits canStand=true, skipped=false',
        (tester) async {
      final repo = _CapturingRepository();
      var closed = false;
      await tester.pumpWidget(_wrap(
        repo: repo,
        event: _stubEvent(),
        onClose: () => closed = true,
        testCountdownOverride: const Duration(seconds: 30),
      ));

      await tester.tap(find.text('Có, tôi đứng dậy được'));
      // Two pumps: 1st flushes the tap, 2nd lets the awaited
      // submitSurvey microtask resolve.
      await tester.pump();
      await tester.pump();

      expect(repo.submitCalls, 1);
      expect(repo.lastCanStand, true);
      expect(repo.lastSkipped, false);
      expect(closed, isTrue, reason: 'After submit, onClose must fire');
    });

    testWidgets('tap "Không" → submits canStand=false, skipped=false',
        (tester) async {
      final repo = _CapturingRepository();
      var closed = false;
      await tester.pumpWidget(_wrap(
        repo: repo,
        event: _stubEvent(),
        onClose: () => closed = true,
        testCountdownOverride: const Duration(seconds: 30),
      ));

      await tester.tap(find.text('Không, cần ai đó giúp'));
      await tester.pump();
      await tester.pump();

      expect(repo.submitCalls, 1);
      expect(repo.lastCanStand, false);
      expect(repo.lastSkipped, false);
      expect(closed, isTrue);
    });

    testWidgets('tap "Bỏ qua" → submits canStand=null, skipped=true',
        (tester) async {
      final repo = _CapturingRepository();
      var closed = false;
      await tester.pumpWidget(_wrap(
        repo: repo,
        event: _stubEvent(),
        onClose: () => closed = true,
        testCountdownOverride: const Duration(seconds: 30),
      ));

      await tester.tap(find.text('Bỏ qua'));
      await tester.pump();
      await tester.pump();

      expect(repo.submitCalls, 1);
      expect(repo.lastCanStand, isNull);
      expect(repo.lastSkipped, true);
      expect(closed, isTrue);
    });

    testWidgets('timer expiry → submits canStand=null, skipped=true',
        (tester) async {
      final repo = _CapturingRepository();
      var closed = false;
      // 200 ms test countdown so the test can wait it out without
      // burning real time.  Ring tick interval defaults to 100 ms.
      await tester.pumpWidget(_wrap(
        repo: repo,
        event: _stubEvent(),
        onClose: () => closed = true,
        testCountdownOverride: const Duration(milliseconds: 200),
      ));

      // Advance past the countdown.  Two extra pumps for the
      // post-frame callback + the awaited submit microtask.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      await tester.pump();

      expect(repo.submitCalls, 1, reason: 'Auto-skip should fire on timeout');
      expect(repo.lastCanStand, isNull);
      expect(repo.lastSkipped, true);
      expect(closed, isTrue);
    });

    testWidgets('double-tap is idempotent (submit fires only once)',
        (tester) async {
      final repo = _CapturingRepository();
      var closeCount = 0;
      await tester.pumpWidget(_wrap(
        repo: repo,
        event: _stubEvent(),
        onClose: () => closeCount++,
        testCountdownOverride: const Duration(seconds: 30),
      ));

      // Tap "Có" rapidly twice.  The internal _submitted guard +
      // FilledButton.onPressed=null while in-flight should prevent
      // a second submit.
      final button = find.text('Có, tôi đứng dậy được');
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await tester.pump();

      expect(repo.submitCalls, 1);
      expect(closeCount, 1);
    });
  });
}
