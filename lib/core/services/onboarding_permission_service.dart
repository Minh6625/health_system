import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

/// F-15 (P-3): one-time permission primer for the SOS location feature.
///
/// **Why this exists.** Tester report (P-3): every time the user fires
/// an SOS the OS prompts for location permission again. Root cause is
/// that `manual_sos_screen` calls `Geolocator.requestPermission()`
/// inside the SOS countdown flow, which means:
///
///   1. The user is in panic-mode and may tap "Don't allow" by accident.
///   2. OS keeps re-asking on subsequent SOS attempts because the
///      previous decision was "denied".
///   3. There is no chance to *explain* why we need location before the
///      OS prompt fires, so the conversion rate of permission grants
///      is suboptimal.
///
/// **What we do.** Show a one-time educational primer (a bottom-sheet)
/// at the first dashboard mount per install that:
///
///   - Explains the SOS use case in Vietnamese.
///   - Lets the user opt in by tapping "Cho phép" → triggers the OS
///     prompt with full context.
///   - Lets the user opt out by tapping "Để sau" → primer is marked
///     shown but no OS prompt fires; SOS flow falls back to the
///     in-flow request like before.
///
/// **What we explicitly avoid.** We do NOT call
/// `Geolocator.requestPermission()` automatically at startup — that
/// violates Apple App Store guideline 5.1.1 (permissions must be
/// requested at moment-of-use with clear context). The primer makes
/// the moment-of-use clear via the explicit "Cho phép" tap.
///
/// **Persistence.** Uses [FlutterSecureStorage] (same store as auth
/// tokens and `clinician_audience_provider`) so we don't introduce a
/// new package dependency just for one boolean flag.
class OnboardingPermissionService {
  /// Storage key. Suffix `_v1` so a future migration (e.g. show the
  /// primer again after a feature change) can land alongside without
  /// clobbering existing users' "already saw it" bit.
  static const String storageKey = 'onboarding_location_primer_shown_v1';

  OnboardingPermissionService({
    FlutterSecureStorage? storage,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission;

  final FlutterSecureStorage _storage;
  // F-15 (P-3): injectable Geolocator hooks. Production paths default
  // to the static [Geolocator.checkPermission] / [Geolocator.requestPermission]
  // calls; unit tests pass fakes so we don't need MethodChannel
  // plumbing to verify the gating + persistence logic.
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;

  /// Returns `true` if the primer should be shown to the user right
  /// now. Encapsulates three independent checks so callers don't have
  /// to think about the truth table:
  ///
  ///   - `false` if the primer was already shown previously (we never
  ///     re-prompt on the same install).
  ///   - `false` if the OS permission is already granted
  ///     (`whileInUse` / `always`) — no need to educate the user about
  ///     a setting that's already on.
  ///   - `false` if the OS permission is `deniedForever`/`unableToDetermine`
  ///     — at that point only Settings can fix it; an in-app primer
  ///     would be a dead-end.
  ///   - `true` only when the user has never seen the primer AND the
  ///     OS is in a state where a fresh `requestPermission` call would
  ///     surface a dialog.
  ///
  /// Failure of secure-storage reads / Geolocator status checks is
  /// treated as "do not show" — better to skip an educational nudge
  /// than to show it on every cold start because storage was flaky.
  Future<bool> shouldShowLocationPrimer() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == 'true') return false;
    } catch (e) {
      debugPrint('OnboardingPermissionService read failed: $e');
      // Be conservative on storage failure: don't nag the user if we
      // cannot reliably tell whether they have seen it.
      return false;
    }

    try {
      final permission = await _checkPermission();
      // Only show the primer when a fresh request would actually
      // surface an OS dialog. `denied` is the one state where this is
      // true — every other state is either already-granted or
      // unrecoverable from in-app.
      if (permission != LocationPermission.denied) return false;
    } catch (e) {
      debugPrint('OnboardingPermissionService permission check failed: $e');
      return false;
    }
    return true;
  }

  /// Persist the "user has seen the primer" flag. Called whether the
  /// user tapped "Cho phép" or "Để sau" — both outcomes count as
  /// shown so the primer never reappears on the same install.
  ///
  /// On a write failure the in-memory call site already navigated
  /// past the primer, so a subsequent app start *might* re-show it.
  /// That's a one-restart regression at worst, not data loss.
  Future<void> markLocationPrimerShown() async {
    try {
      await _storage.write(key: storageKey, value: 'true');
    } catch (e) {
      debugPrint('OnboardingPermissionService write failed: $e');
    }
  }

  /// Trigger the OS-level location permission dialog. Returns the
  /// resulting permission state. Caller decides whether to navigate
  /// the user to the SOS settings or to silently move on.
  ///
  /// Wrapped in try/catch because `Geolocator.requestPermission` can
  /// throw on some Android emulators with a missing Google Play
  /// Services binding — we don't want a primer tap to crash the
  /// dashboard.
  Future<LocationPermission> requestLocationPermission() async {
    try {
      return await _requestPermission();
    } catch (e) {
      debugPrint('OnboardingPermissionService request failed: $e');
      return LocationPermission.denied;
    }
  }
}
