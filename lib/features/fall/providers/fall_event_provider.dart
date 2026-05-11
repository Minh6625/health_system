import 'package:flutter/foundation.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';
import 'package:healthguard/features/fall/repositories/fall_event_repository.dart';

enum FallEventLoadState { initial, loading, success, empty, error }

/// State for the fall-events screens — list, detail, and dismiss.
///
/// Phase 4B-full slice 2c (mobile half). Uses [ChangeNotifier] to
/// match the existing `SleepProvider` pattern; switching to Riverpod
/// is plan-deferred (Phase 8 mobile-architecture follow-up).
class FallEventProvider extends ChangeNotifier {
  FallEventProvider({FallEventRepository? repository})
    : _repository = repository ?? FallEventRepositoryImpl();

  final FallEventRepository _repository;

  // ── List state ──────────────────────────────────────────────────────────

  FallEventLoadState _listState = FallEventLoadState.initial;
  List<FallEvent> _events = const [];
  int _totalCount = 0;
  String? _listErrorMessage;

  FallEventLoadState get listState => _listState;
  List<FallEvent> get events => _events;
  int get totalCount => _totalCount;
  String? get listErrorMessage => _listErrorMessage;

  /// Convenience: the most recent ACTIVE event (status == detected /
  /// unknown). Used by the home banner to decide whether to render
  /// the "fall detected" call-to-action.
  FallEvent? get latestActiveEvent {
    for (final event in _events) {
      if (event.status.isActive) return event;
    }
    return null;
  }

  // ── Dismiss state ───────────────────────────────────────────────────────

  bool _dismissInFlight = false;
  String? _dismissErrorMessage;

  bool get isDismissing => _dismissInFlight;
  String? get dismissErrorMessage => _dismissErrorMessage;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Refresh the list of fall events. Caller decides the page size +
  /// offset; default page is the 20 newest events.
  ///
  /// Errors don't clear the existing list — UX is "show what we had,
  /// surface a retry button" rather than wiping the screen on a
  /// transient network blip.
  Future<void> refresh({
    int limit = 20,
    int offset = 0,
    String? patientId,
  }) async {
    _listState = FallEventLoadState.loading;
    _listErrorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.listEvents(
        limit: limit,
        offset: offset,
        patientId: patientId,
      );
      _events = result.items;
      _totalCount = result.total;
      _listState = result.items.isEmpty
          ? FallEventLoadState.empty
          : FallEventLoadState.success;
    } catch (e) {
      _listErrorMessage = e.toString();
      _listState = FallEventLoadState.error;
    }
    notifyListeners();
  }

  /// Dismiss one event. Returns ``true`` when the dismiss succeeded.
  ///
  /// Optimistically updates the local state on success so the UI
  /// reflects the new ``dismissed`` status without waiting for a list
  /// refresh. On 404 (event not found / not yours) returns ``false``
  /// without throwing — the caller usually shows a "đã hết hạn"
  /// banner.
  Future<bool> dismiss(
    int eventId, {
    String? reason,
    String? patientId,
  }) async {
    _dismissInFlight = true;
    _dismissErrorMessage = null;
    notifyListeners();

    bool ok = false;
    try {
      final updated = await _repository.dismiss(
        eventId,
        reason: reason,
        patientId: patientId,
      );
      if (updated != null) {
        _events = [
          for (final event in _events)
            if (event.id == updated.id) updated else event,
        ];
        ok = true;
      }
    } catch (e) {
      _dismissErrorMessage = e.toString();
    } finally {
      _dismissInFlight = false;
      notifyListeners();
    }
    return ok;
  }

  /// Fetch one event detail. Bypasses the list cache so caregiver
  /// flows that deep-link into a specific event always see the
  /// latest server state.
  Future<FallEvent?> fetchDetail(int id, {String? patientId}) {
    return _repository.getEvent(id, patientId: patientId);
  }

  // ── Survey state (Module FA-2 — Option 3-Lite) ──────────────────────────

  bool _surveyInFlight = false;
  String? _surveyErrorMessage;

  bool get isSubmittingSurvey => _surveyInFlight;
  String? get surveyErrorMessage => _surveyErrorMessage;

  /// Submit the post-dismiss stand-up survey answer (Option 3-Lite).
  ///
  /// Returns ``true`` on success.  Optimistically updates the local
  /// list so the survey badge appears immediately.  ``null`` server
  /// response (404 or wrong shape) yields ``false`` without throwing.
  Future<bool> submitSurvey(
    int eventId, {
    required bool? canStand,
    required bool skipped,
    String? patientId,
  }) async {
    _surveyInFlight = true;
    _surveyErrorMessage = null;
    notifyListeners();

    bool ok = false;
    try {
      final updated = await _repository.submitSurvey(
        eventId,
        canStand: canStand,
        skipped: skipped,
        patientId: patientId,
      );
      if (updated != null) {
        _events = [
          for (final event in _events)
            if (event.id == updated.id) updated else event,
        ];
        ok = true;
      }
    } catch (e) {
      _surveyErrorMessage = e.toString();
    } finally {
      _surveyInFlight = false;
      notifyListeners();
    }
    return ok;
  }

  /// Test hook so the FallAlertScreen can stub a known fall event in
  /// without going through the network. Public on the provider so
  /// integration tests that boot the real FallEventProvider can
  /// inject a synthetic event.
  @visibleForTesting
  void debugSetEvents(List<FallEvent> events, {int? totalCount}) {
    _events = List.unmodifiable(events);
    _totalCount = totalCount ?? events.length;
    _listState = events.isEmpty
        ? FallEventLoadState.empty
        : FallEventLoadState.success;
    notifyListeners();
  }
}
