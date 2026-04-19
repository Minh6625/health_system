import 'package:flutter/material.dart';
import '../domain/entities/risk_history_entity.dart';
import '../repositories/risk_analysis_repository.dart';

class RiskHistoryProvider extends ChangeNotifier {
  RiskHistoryProvider({RiskAnalysisRepository? repository})
    : _repository = repository ?? RiskAnalysisRepository();

  final RiskAnalysisRepository _repository;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  RiskHistorySummary? _summary;
  final List<RiskHistoryItemEntity> _items = [];
  String _currentRange = '7d';
  int _currentPage = 1;
  bool _hasMore = true;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  RiskHistorySummary? get summary => _summary;
  List<RiskHistoryItemEntity> get items => _items;
  String get currentRange => _currentRange;
  bool get hasMore => _hasMore;

  Future<void> fetchHistory({
    required String? profileId,
    String range = '7d',
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _items.clear();
      _hasMore = true;
    }

    if (_currentPage == 1) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _currentRange = range;
    _error = null;
    notifyListeners();

    try {
      final history = await _repository.fetchHistory(
        profileId: profileId,
        range: range,
        page: _currentPage,
        limit: 20,
      );

      _summary = history.summary;
      _items.addAll(history.items);
      _hasMore = history.hasMore;
      _currentPage = history.page + 1;
    } catch (e) {
      _error = 'Lỗi khi tải lịch sử: $e';
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void changeRange(String? profileId, String newRange) {
    if (newRange == _currentRange) return;
    fetchHistory(profileId: profileId, range: newRange, refresh: true);
  }

  void loadMore(String? profileId) {
    if (_hasMore && !_isLoading && !_isLoadingMore) {
      fetchHistory(profileId: profileId, range: _currentRange, refresh: false);
    }
  }
}
