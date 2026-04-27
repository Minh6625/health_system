import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's "Chế độ chuyên môn" toggle and surfaces it to
/// the rest of the app.
///
/// Phase 8 / Phase 4B-full slice 4a (see baseline doc §7g
/// "What's deferred"). When enabled, the
/// [RiskAnalysisRepository.fetchReportDetail] sends
/// ``?audience=clinician`` so the backend returns the
/// :class:`RiskReportClinicianResponse` shape with raw SHAP +
/// model_request_id. Patient-mode users never see the toggle —
/// the screen gates it on the auth provider's user role.
///
/// Persistence uses [FlutterSecureStorage] (the same store the auth
/// flow already depends on) rather than ``shared_preferences`` so we
/// don't have to add a new package + audit it for storing this kind
/// of UX preference next to the auth tokens.
class ClinicianAudienceProvider extends ChangeNotifier {
  /// Storage key. Suffix ``_v1`` so a future migration (e.g. to a
  /// per-profile setting) can land alongside without clobbering an
  /// existing user's value.
  static const String storageKey = 'clinician_audience_enabled_v1';

  /// Audience string sent on the wire when the toggle is on. Mirrors
  /// the backend's ``CLINICIAN_ROLES`` audience enum value (see
  /// ``backend/app/core/audience.py::AudienceEnum``).
  static const String audienceWhenEnabled = 'clinician';

  ClinicianAudienceProvider({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  bool _enabled = false;
  bool _isInitialized = false;

  /// True while the secure-storage read is still in flight. The UI
  /// can show a skeleton or just hide the toggle until this clears.
  bool get isInitialized => _isInitialized;

  /// Current value. ``false`` until [init] resolves.
  bool get enabled => _enabled;

  /// The audience string to append to ``GET /risk-reports/{id}``
  /// requests — ``"clinician"`` when the toggle is on, ``null`` to
  /// keep the default patient flow.
  String? get audienceQueryValue => _enabled ? audienceWhenEnabled : null;

  /// Hydrate the in-memory flag from secure storage.
  ///
  /// Idempotent: subsequent calls are a no-op. Failure (key absent,
  /// secure-storage unavailable, malformed value) is treated as
  /// "toggle off" — leaks no clinical content if storage fails.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final raw = await _storage.read(key: storageKey);
      _enabled = raw == 'true';
    } catch (e) {
      debugPrint('ClinicianAudienceProvider init failed: $e');
      _enabled = false;
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Set the toggle and persist. Safe to call before [init] (the
  /// new value will overwrite whatever's on disk).
  ///
  /// On a write failure the in-memory flag still updates so the UI
  /// reflects the user's tap; the next app start will fall back to
  /// the previously-persisted value, but that's a one-restart
  /// regression at worst rather than a silent fail.
  Future<void> setEnabled(bool value) async {
    if (_enabled == value && _isInitialized) return;
    _enabled = value;
    _isInitialized = true;
    notifyListeners();
    try {
      await _storage.write(key: storageKey, value: value.toString());
    } catch (e) {
      debugPrint('ClinicianAudienceProvider write failed: $e');
    }
  }

  /// Test hook — bypass the [init] secure-storage round-trip and
  /// seed an in-memory value directly.
  @visibleForTesting
  void debugSetState({required bool enabled, bool isInitialized = true}) {
    _enabled = enabled;
    _isInitialized = isInitialized;
    notifyListeners();
  }
}
