import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/repositories/mock_sleep_repository.dart';
import 'package:healthguard/features/sleep_analysis/repositories/sleep_repository.dart';

enum SleepLoadState { initial, loading, success, empty, error }

class SleepProvider extends ChangeNotifier {
  /// 🔧 ĐỔI THÀNH false khi backend API đã sẵn sàng
  static const bool _useMock = true;

  /// Cache TTL = 1 phút
  static const _cacheTTL = Duration(minutes: 1);

  SleepProvider({SleepRepository? repository})
      : _repository = repository ?? (_useMock ? MockSleepRepository() : SleepRepositoryImpl());

  final SleepRepository _repository;

  // ── State ─────────────────────────────────────────────────────────────────

  SleepLoadState _loadState = SleepLoadState.initial;

  SleepSession? _latestSession;
  SleepSession? _selectedSession;
  List<SleepSession> _historyList = [];
  String? _errorMessage;
  String? _patientId;
  DateTime _selectedDate = DateTime.now();
  bool _dateLoading = false;

  /// Timestamp của lần loadAll() thành công gần nhất (dùng cho cache)
  DateTime? _lastFetchTime;

  // ── Getters ───────────────────────────────────────────────────────────────

  SleepLoadState get loadState => _loadState;
  SleepSession? get latestSession => _latestSession;
  SleepSession? get selectedSession => _selectedSession;
  List<SleepSession> get historyList => List.unmodifiable(_historyList);
  String? get errorMessage => _errorMessage;
  String? get patientId => _patientId;
  DateTime get selectedDate => _selectedDate;
  bool get dateLoading => _dateLoading;

  bool get isLoading => _loadState == SleepLoadState.loading;
  bool get isEmpty => _loadState == SleepLoadState.empty;
  bool get hasError => _loadState == SleepLoadState.error;
  bool get isSuccess => _loadState == SleepLoadState.success;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Loads latest + 7-day history in parallel.
  /// Skips API call if cache is still fresh (< 1 minute).
  Future<void> loadAll({String? patientId, bool forceRefresh = false}) async {
    if (patientId != null) _patientId = patientId;

    // Return cached data immediately if within TTL and already has data
    if (!forceRefresh && _isCacheValid()) {
      // Already in success state with valid cache – no UI flicker needed
      return;
    }

    _loadState = SleepLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));

      final results = await Future.wait([
        _repository.getLatestSleep(patientId: _patientId),
        _repository.getSleepHistory(
          from: from,
          to: now,
          patientId: _patientId,
        ),
      ]);

      _latestSession = results[0] as SleepSession?;
      _historyList = results[1] as List<SleepSession>;
      _selectedSession = _latestSession;
      _selectedDate = _latestSession?.endTime ?? DateTime.now();

      if (_latestSession == null && _historyList.isEmpty) {
        _loadState = SleepLoadState.empty;
      } else {
        _loadState = SleepLoadState.success;
        _lastFetchTime = DateTime.now(); // ✅ stamp cache
      }
    } catch (e) {
      _errorMessage = _friendlyError(e);
      _loadState = SleepLoadState.error;
    }

    notifyListeners();
  }

  /// RefreshIndicator: always forces a fresh fetch, bypassing cache
  Future<void> fetchLatestSleep({String? patientId}) async {
    if (patientId != null) _patientId = patientId;
    await loadAll(patientId: _patientId, forceRefresh: true);
  }

  /// Called when user picks a date from DatePicker or weekly strip.
  Future<void> selectDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    _selectedDate = day;
    _dateLoading = true;
    notifyListeners();

    try {
      final session = await _repository.getSessionByDate(day, patientId: _patientId);
      _selectedSession = session;
    } catch (_) {
      // keep previous selectedSession on error
    } finally {
      _dateLoading = false;
      notifyListeners();
    }
  }

  /// Called when user taps a bar in SleepTrendChart.
  void selectHistorySession(SleepSession session) {
    _selectedSession = session;
    _selectedDate = session.endTime;
    notifyListeners();
  }

  void setPatient(String patientId) {
    _patientId = patientId;
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  bool _isCacheValid() {
    if (_lastFetchTime == null) return false;
    if (_loadState != SleepLoadState.success) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheTTL;
  }

  // ── Error helpers ─────────────────────────────────────────────────────────

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
}
