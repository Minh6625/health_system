import 'package:flutter/material.dart';
import '../domain/entities/risk_history_entity.dart';
import '../repositories/risk_analysis_repository.dart';

class RiskHistoryProvider extends ChangeNotifier {
  RiskHistoryProvider({RiskAnalysisRepository? repository})
    : _repository = repository ?? RiskAnalysisRepository();

  final RiskAnalysisRepository _repository;

  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _paginationError;
  bool _hasLoaded = false;

  RiskHistorySummary? _summary;
  final List<RiskHistoryItemEntity> _items = [];
  String _currentRange = '7d';
  int _currentPage = 1;
  bool _hasMore = true;
  int _activeRequestId = 0;

  bool get isLoading => _isInitialLoading || _isRefreshing;
  bool get isInitialLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String? get paginationError => _paginationError;
  RiskHistorySummary? get summary => _summary;
  List<RiskHistoryItemEntity> get items => _items;
  String get currentRange => _currentRange;
  bool get hasMore => _hasMore;
  bool get isEmpty =>
      _hasLoaded && _items.isEmpty && _error == null && !_isInitialLoading;
  bool get hasSummary => _summary != null && _items.isNotEmpty;

  Future<void> fetchHistory({
    required String? profileId,
    String range = '7d',
    bool refresh = false,
  }) async {
    final requestId = ++_activeRequestId;
    final isLoadingFirstPage = _currentPage == 1 || refresh || !_hasLoaded;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (isLoadingFirstPage) {
      if (_items.isEmpty) {
        _isInitialLoading = true;
      } else {
        _isRefreshing = true;
      }
    } else {
      _isLoadingMore = true;
    }
    _currentRange = range;
    if (!refresh && !isLoadingFirstPage) {
      _paginationError = null;
    } else {
      _error = null;
    }
    notifyListeners();

    try {
      final history = await _repository.fetchHistory(
        profileId: profileId,
        range: range,
        page: _currentPage,
        limit: 20,
      );

      if (requestId != _activeRequestId) return;

      _summary = history.summary;
      if (history.page == 1) {
        _items
          ..clear()
          ..addAll(history.items);
      } else {
        _items.addAll(history.items);
      }
      _hasMore = history.hasMore;
      _currentPage = history.page + 1;
      _hasLoaded = true;
      _error = null;
      _paginationError = null;
    } catch (e) {
      if (requestId != _activeRequestId) return;

      if (_isLoadingMore) {
        _paginationError = 'Không thể tải thêm dữ liệu: $e';
      } else {
        _error = 'Lỗi khi tải lịch sử: $e';
        _hasLoaded = true;
      }
    } finally {
      if (requestId == _activeRequestId) {
        _isInitialLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeRange(String? profileId, String newRange) async {
    if (newRange == _currentRange) return;
    await fetchHistory(profileId: profileId, range: newRange, refresh: true);
  }

  void loadMore(String? profileId) {
    if (_hasMore && !_isInitialLoading && !_isRefreshing && !_isLoadingMore) {
      fetchHistory(profileId: profileId, range: _currentRange, refresh: false);
    }
  }
}
