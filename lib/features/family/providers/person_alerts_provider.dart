import 'package:flutter/foundation.dart';

import '../models/recent_alert_item.dart';
import '../repositories/family_repository.dart';

/// State machine for the "Cảnh báo gần đây" section on PersonDetailScreen.
///
/// Five terminal-ish states:
///   * [initial]          — provider created but ``load`` not yet called.
///   * [loading]          — request in flight; UI shows skeleton.
///   * [granted]          — permission ok. ``items`` may be empty (quiet
///                          window) or populated.
///   * [permissionDenied] — caregiver lacks ``can_receive_alerts`` for this
///                          patient. UI shows the dedicated banner instead
///                          of an error.
///   * [error]            — anything else (network, 5xx, parse). UI shows
///                          inline retry without destroying the section.
enum PersonAlertsStatus {
  initial,
  loading,
  granted,
  permissionDenied,
  error,
}

class PersonAlertsProvider extends ChangeNotifier {
  PersonAlertsProvider({FamilyRepository? repository})
    : _repository = repository ?? FamilyRepository();

  final FamilyRepository _repository;

  PersonAlertsStatus _status = PersonAlertsStatus.initial;
  List<RecentAlertItem> _items = const <RecentAlertItem>[];
  String? _errorMessage;
  int _windowDays = 7;
  // Token guards against out-of-order responses if the user pulls-to-refresh
  // mid-flight: only the latest call's result is allowed to mutate state.
  int _activeRequestToken = 0;

  PersonAlertsStatus get status => _status;
  List<RecentAlertItem> get items => _items;
  String? get errorMessage => _errorMessage;
  int get windowDays => _windowDays;

  bool get isLoading => _status == PersonAlertsStatus.loading;
  bool get isPermissionDenied =>
      _status == PersonAlertsStatus.permissionDenied;
  bool get isReady => _status == PersonAlertsStatus.granted;
  bool get hasError => _status == PersonAlertsStatus.error;

  /// Load (or reload) the recent alerts for [patientUserId].
  ///
  /// The argument is a string because the rest of the family feature carries
  /// ``profileId`` as a string (see ``FamilyProfileSnapshot.id``); we parse
  /// at the boundary so the provider can fail fast on a malformed id rather
  /// than letting a NaN reach the API. A non-numeric id is treated as an
  /// error state — the dashboard schema guarantees numeric ids.
  Future<void> load(
    String patientUserId, {
    int days = 7,
    int limit = 10,
  }) async {
    final parsed = int.tryParse(patientUserId);
    if (parsed == null) {
      _status = PersonAlertsStatus.error;
      _items = const <RecentAlertItem>[];
      _errorMessage = 'Không xác định được người dùng để tải cảnh báo.';
      notifyListeners();
      return;
    }

    final token = ++_activeRequestToken;
    _status = PersonAlertsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.fetchRecentAlerts(
        parsed,
        days: days,
        limit: limit,
      );
      if (token != _activeRequestToken) return;

      _items = response.items;
      _windowDays = response.windowDays;
      _status = PersonAlertsStatus.granted;
      _errorMessage = null;
      notifyListeners();
    } on RecentAlertsPermissionDeniedException catch (e) {
      if (token != _activeRequestToken) return;
      _items = const <RecentAlertItem>[];
      _status = PersonAlertsStatus.permissionDenied;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      if (token != _activeRequestToken) return;
      _items = const <RecentAlertItem>[];
      _status = PersonAlertsStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Convenience for pull-to-refresh / retry button — preserves the same
  /// window/limit the section was originally loaded with.
  Future<void> reload(String patientUserId) =>
      load(patientUserId, days: _windowDays);
}
