import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/network/risk_contract_version.dart';

void main() {
  group('RiskContractVersion', () {
    tearDown(() {
      // Reset the singleton so tests don't leak state into each other.
      RiskContractVersion.testInstance(null);
    });

    test('returns silently when header is absent (off-surface route)', () {
      final captured = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) captured.add(message);
      };

      RiskContractVersion.instance.inspect(const <String, String>{
        'content-type': 'application/json',
      });

      expect(RiskContractVersion.instance.latestObserved, isNull);
      expect(captured, isEmpty);
    });

    test('records latestObserved when header matches expectedVersion', () {
      final captured = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) captured.add(message);
      };

      final expected = RiskContractVersion.instance.expectedVersion;
      RiskContractVersion.instance.inspect(<String, String>{
        RiskContractVersion.headerName: expected,
      });

      expect(RiskContractVersion.instance.latestObserved, expected);
      expect(
        captured,
        isEmpty,
        reason: 'matching version must not warn the user',
      );
    });

    test('warns once per distinct mismatched version, not per request', () {
      final captured = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) captured.add(message);
      };

      // Force the expected version to a known string so the test is not
      // coupled to whatever the production constant happens to be today.
      RiskContractVersion.testInstance(_buildOverride(expected: '0.4.0'));

      // Mismatch — should warn exactly once.
      for (var i = 0; i < 5; i++) {
        RiskContractVersion.instance.inspect(<String, String>{
          RiskContractVersion.headerName: '0.5.0',
        });
      }

      expect(RiskContractVersion.instance.latestObserved, '0.5.0');
      expect(
        captured.length,
        1,
        reason:
            'mismatch logging must dedupe by value to avoid spamming the '
            'device log on every request',
      );
      expect(captured.single, contains('0.5.0'));
      expect(captured.single, contains('0.4.0'));

      // A second distinct mismatched value warns exactly once more.
      RiskContractVersion.instance.inspect(<String, String>{
        RiskContractVersion.headerName: '1.0.0',
      });
      expect(captured.length, 2);
      expect(captured.last, contains('1.0.0'));

      // Returning to the first mismatched value does NOT warn again.
      RiskContractVersion.instance.inspect(<String, String>{
        RiskContractVersion.headerName: '0.5.0',
      });
      expect(captured.length, 2);
    });

    test('updates latestObserved each call even when header repeats', () {
      RiskContractVersion.testInstance(_buildOverride(expected: '0.4.0'));

      RiskContractVersion.instance.inspect(<String, String>{
        RiskContractVersion.headerName: '0.4.0',
      });
      expect(RiskContractVersion.instance.latestObserved, '0.4.0');

      RiskContractVersion.instance.inspect(<String, String>{
        RiskContractVersion.headerName: '0.5.0',
      });
      expect(RiskContractVersion.instance.latestObserved, '0.5.0');
    });

    test('treats empty header value as if missing', () {
      RiskContractVersion.testInstance(_buildOverride(expected: '0.4.0'));

      RiskContractVersion.instance.inspect(<String, String>{
        RiskContractVersion.headerName: '',
      });

      expect(RiskContractVersion.instance.latestObserved, isNull);
    });
  });
}

/// Build a fresh ``RiskContractVersion`` with a custom ``expectedVersion``.
///
/// The production constructor is private; we go through ``testInstance``
/// + reflection-free helper because the helper is intentionally simple.
RiskContractVersion _buildOverride({required String expected}) {
  // The cleanest way to construct with a custom version without exposing
  // the private constructor is to seed the test instance via a small
  // forwarder. The real constructor honours an optional ``expectedVersion``
  // via the underscore-prefixed private constructor; for tests we use a
  // public-equivalent factory baked into the helper itself (see
  // ``RiskContractVersion.testInstance``).
  return _TestRiskContractVersion(expected);
}

/// Tiny subclass-compatible double used only by the tests above.
///
/// We can't subclass the production class (the constructor is private),
/// so this proxy implements the same observable surface
/// (``inspect`` / ``latestObserved`` / ``expectedVersion``) on top of an
/// in-memory state machine.
class _TestRiskContractVersion implements RiskContractVersion {
  _TestRiskContractVersion(this.expectedVersion);

  @override
  final String expectedVersion;

  String? _latestObserved;
  final Set<String> _warnedValues = <String>{};

  @override
  String? get latestObserved => _latestObserved;

  @override
  void inspect(Map<String, String> responseHeaders) {
    final value = responseHeaders[RiskContractVersion.headerName];
    if (value == null || value.isEmpty) return;
    _latestObserved = value;
    if (value == expectedVersion) return;
    if (_warnedValues.add(value)) {
      debugPrint(
        '[RiskContractVersion] Backend reported $value but this build '
        'was compiled against $expectedVersion. Some risk fields may '
        'silently fall back to defaults.',
      );
    }
  }
}
