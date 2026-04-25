import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';

enum SleepLoadState { initial, loading, success, empty, error, noDataYet }

class SleepProvider extends ChangeNotifier {
  static const _cacheTTL = Duration(minutes: 1);

  SleepProvider({SleepRepository? repository, DateTime Function()? now})
    : _repository = repository ?? SleepRepositoryImpl(),
      _now = now ?? DateTime.now;

  final SleepRepository _repository;
  final DateTime Function() _now;

  SleepLoadState _loadState = SleepLoadState.initial;

  SleepSession? _latestSession;
  SleepSession? _selectedSession;
  List<SleepSession> _historyList = [];
  String? _errorMessage;
  String? _dateErrorMessage;
  String? _patientId;
  DateTime _selectedDate = DateTime.now();
  bool _dateLoading = false;

  DateTime? _lastFetchTime;

  SleepLoadState get loadState => _loadState;
  SleepSession? get latestSession => _latestSession;
  SleepSession? get selectedSession => _selectedSession;
  List<SleepSession> get historyList => List.unmodifiable(_historyList);
  String? get errorMessage => _errorMessage;
  String? get dateErrorMessage => _dateErrorMessage;
  String? get patientId => _patientId;
  DateTime get selectedDate => _selectedDate;
  bool get dateLoading => _dateLoading;
  DateTime get currentTime => _now();

  bool get isLoading => _loadState == SleepLoadState.loading;
  bool get isEmpty => _loadState == SleepLoadState.empty;
  bool get hasError => _loadState == SleepLoadState.error;
  bool get isSuccess => _loadState == SleepLoadState.success;
  bool get isNoDataYet => _loadState == SleepLoadState.noDataYet;
  bool get hasDateError => _dateErrorMessage != null;

  Future<void> loadAll({
    String? patientId,
    bool forceRefresh = false,
    DateTime? preferredDate,
  }) async {
    _applyPatientContext(patientId);
    final normalizedPreferredDate = _normalizeDay(preferredDate);

    // Return cached data immediately if within TTL and already has data
    if (!forceRefresh && _isCacheValid()) {
      if (normalizedPreferredDate != null &&
          !_isSameDay(_selectedDate, normalizedPreferredDate)) {
        await selectDate(normalizedPreferredDate);
      }
      return;
    }

    _loadState = SleepLoadState.loading;
    _errorMessage = null;
    _dateErrorMessage = null;
    notifyListeners();

    try {
      final now = _now();
      final from = now.subtract(const Duration(days: 7));

      final results = await Future.wait([
        _repository.getLatestSleep(patientId: _patientId),
        _repository.getSleepHistory(from: from, to: now, patientId: _patientId),
      ]);

      _latestSession = results[0] as SleepSession?;
      _historyList = results[1] as List<SleepSession>;
      final fallbackSession = _latestSession ?? _historyList.firstOrNull;
      SleepSession? preferredSession;
      if (normalizedPreferredDate != null) {
        preferredSession =
            _sessionForDate(_historyList, normalizedPreferredDate) ??
            (fallbackSession != null &&
                    _isSameDay(
                      fallbackSession.sleepDate,
                      normalizedPreferredDate,
                    )
                ? fallbackSession
                : null);
        if (preferredSession == null &&
            !_isCurrentDayBeforeSixAm(normalizedPreferredDate)) {
          preferredSession = await _repository.getSessionByDate(
            normalizedPreferredDate,
            patientId: _patientId,
          );
        }
      }

      final showNoDataYet =
          normalizedPreferredDate != null &&
          _isCurrentDayBeforeSixAm(normalizedPreferredDate) &&
          preferredSession == null;
      _selectedSession = showNoDataYet
          ? null
          : preferredSession ?? fallbackSession;
      _selectedDate =
          normalizedPreferredDate ?? _selectedSession?.sleepDate ?? _now();

      if (_selectedSession == null) {
        if (showNoDataYet) {
          _loadState = SleepLoadState.noDataYet;
        } else if (_latestSession == null && _historyList.isEmpty) {
          _loadState = SleepLoadState.empty;
        } else {
          _loadState = SleepLoadState.empty;
        }
      } else {
        _loadState = SleepLoadState.success;
        _lastFetchTime = _now();
      }
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _loadState = SleepLoadState.error;
    }

    notifyListeners();
  }

  Future<void> fetchLatestSleep({String? patientId}) async {
    _applyPatientContext(patientId);
    await loadAll(patientId: _patientId, forceRefresh: true);
  }

  Future<void> selectDate(DateTime date) async {
    final day = _normalizeDay(date)!;
    final previousState = _loadState;
    final previousSession = _selectedSession;
    final previousDate = _selectedDate;
    _selectedDate = day;
    _dateErrorMessage = null;

    if (_isCurrentDayBeforeSixAm(day)) {
      _loadState = SleepLoadState.noDataYet;
      _selectedSession = null;
      notifyListeners();
      return;
    }

    _dateLoading = true;
    notifyListeners();

    try {
      final session = await _repository.getSessionByDate(
        day,
        patientId: _patientId,
      );
      _selectedSession = session;
      _loadState = session == null
          ? SleepLoadState.empty
          : SleepLoadState.success;
    } catch (e) {
      _dateErrorMessage = _friendlyError(e);
      _selectedSession = previousSession;
      _selectedDate = previousDate;
      _loadState = previousSession != null
          ? SleepLoadState.success
          : previousState;
    } finally {
      _dateLoading = false;
      notifyListeners();
    }
  }

  void selectHistorySession(SleepSession session) {
    _selectedSession = session;
    _selectedDate = session.sleepDate;
    _dateErrorMessage = null;
    notifyListeners();
  }

  void setPatient(String? patientId) {
    _applyPatientContext(patientId);
  }

  void _applyPatientContext(String? patientId) {
    final normalizedPatientId = _normalizePatientId(patientId);
    if (_patientId == normalizedPatientId) {
      return;
    }

    _patientId = normalizedPatientId;
    _resetCachedState();
  }

  String? _normalizePatientId(String? patientId) {
    if (patientId == null) {
      return null;
    }
    final trimmed = patientId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _resetCachedState() {
    _latestSession = null;
    _selectedSession = null;
    _historyList = [];
    _errorMessage = null;
    _dateErrorMessage = null;
    _dateLoading = false;
    _selectedDate = _now();
    _lastFetchTime = null;
    _loadState = SleepLoadState.initial;
  }

  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    if (_loadState != SleepLoadState.success) return false;
    return _now().difference(_lastFetchTime!) < _cacheTTL;
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Kết nối quá chậm. Vui lòng thử lại.';
    if (msg.contains('socketexception') || msg.contains('network')) {
      return 'Mất kết nối mạng. Vui lòng kiểm tra Wi-Fi/4G.';
    }
    if (msg.contains('formatexception') || msg.contains('type')) {
      return 'Dữ liệu không hợp lệ từ máy chủ.';
    }
    return 'Không thể tải dữ liệu giấc ngủ. Vui lòng thử lại.';
  }

  DateTime? _normalizeDay(DateTime? date) {
    if (date == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day);
  }

  SleepSession? _sessionForDate(List<SleepSession> sessions, DateTime date) {
    for (final session in sessions) {
      if (_isSameDay(session.sleepDate, date)) {
        return session;
      }
    }
    return null;
  }

  bool _isCurrentDayBeforeSixAm(DateTime day) {
    final now = _now();
    return _isSameDay(day, now) && now.hour < 6;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
