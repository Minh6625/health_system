import 'package:flutter/foundation.dart';

/// Mobile-side view of the backend's `X-Risk-Contract-Version` header.
///
/// Phase 6 of the risk-core refactor (see
/// `backend/docs/risk-contract-baseline.md`) tags every response from the
/// mobile risk routes with a version. This helper:
///
///   * Knows the version the *currently shipped binary* was built against
///     (`expectedVersion`).
///   * Reads the version the *backend the binary is talking to* is on
///     (`latestObserved`).
///   * Emits a single `debugPrint` warning the first time a non-matching
///     value is observed, so a stale binary chatting with a newer backend
///     leaves a clear breadcrumb in the device log without spamming.
///
/// The helper is intentionally a singleton: the warning state must persist
/// across all `ApiClient` requests in a session. Tests can swap the
/// instance via `RiskContractVersion.testInstance(...)`.
class RiskContractVersion {
  RiskContractVersion._({String? expectedVersion})
    : expectedVersion = expectedVersion ?? _defaultExpectedVersion;

  /// The version this Flutter binary was built against.
  ///
  /// Sync with `RISK_CONTRACT_VERSION` in
  /// `backend/app/core/risk_contract.py` and with the **Baseline version**
  /// in `backend/docs/risk-contract-baseline.md`.
  static const String _defaultExpectedVersion = '0.4.0';

  /// Header name (must match `RISK_CONTRACT_VERSION_HEADER` on the backend).
  static const String headerName = 'x-risk-contract-version';

  static RiskContractVersion _instance = RiskContractVersion._();

  /// Singleton accessor used by `ApiClient` in production.
  static RiskContractVersion get instance => _instance;

  /// Replace the singleton in tests. Call with `null` to reset.
  @visibleForTesting
  static void testInstance(RiskContractVersion? override) {
    _instance = override ?? RiskContractVersion._();
  }

  final String expectedVersion;

  String? _latestObserved;
  final Set<String> _warnedValues = <String>{};

  /// The most recent contract version the backend reported, or `null` if
  /// nothing has been observed yet.
  String? get latestObserved => _latestObserved;

  /// Inspect a response's headers and record the contract version.
  ///
  /// Header lookup is case-insensitive (the `http` package lowercases keys
  /// but the constant matches that). Returns silently when the header is
  /// missing — most routes are not on the risk surface.
  void inspect(Map<String, String> responseHeaders) {
    final value = responseHeaders[headerName];
    if (value == null || value.isEmpty) {
      return;
    }
    _latestObserved = value;
    if (value == expectedVersion) {
      return;
    }
    if (_warnedValues.add(value)) {
      // ``debugPrint`` is a no-op in release builds, so this is a free
      // debug-only breadcrumb. We do NOT throw / show a banner because
      // the backend could legitimately be ahead of the binary during a
      // staged rollout.
      debugPrint(
        '[RiskContractVersion] Backend reported $value but this build '
        'was compiled against $expectedVersion. Some risk fields may '
        'silently fall back to defaults.',
      );
    }
  }
}
