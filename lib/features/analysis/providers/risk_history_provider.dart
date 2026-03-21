import 'package:flutter/material.dart';
import '../domain/entities/risk_history_entity.dart';
import '../domain/entities/risk_report_entity.dart'; // To access RiskLevel

class RiskHistoryProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  
  RiskHistorySummary? _summary;
  final List<RiskHistoryItemEntity> _items = [];
  String _currentRange = "7d";
  int _currentPage = 1;
  bool _hasMore = true;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  RiskHistorySummary? get summary => _summary;
  List<RiskHistoryItemEntity> get items => _items;
  String get currentRange => _currentRange;
  bool get hasMore => _hasMore;

  Future<void> fetchHistory({required String profileId, String range = "7d", bool refresh = false}) async {
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

    // Mock network
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      // Fake summary for any range
      _summary = RiskHistorySummary(
        averageScore: 41,
        highestScore: 66,
        lowestScore: 28,
        deltaVsPreviousPeriod: -9,
        trendPoints: [62, 58, 54, 49, 45, 43, 41],
      );

      // Create dummy list
      List<RiskHistoryItemEntity> newItems = List.generate(
        10, 
        (index) {
          final dayOffset = ((_currentPage - 1) * 10) + index;
          return RiskHistoryItemEntity(
            reportId: "report_${_currentPage}_$index",
            score: 30 + (index % 10),
            level: index % 3 == 0 ? RiskLevel.moderate : RiskLevel.low,
            analyzedAt: DateTime.now().subtract(Duration(days: dayOffset, hours: index)),
            reasonPreview: "Nhịp tim và SpO2 đã ổn định hơn ngày hôm trước.",
          );
        }
      );

      _items.addAll(newItems);
      _hasMore = _currentPage < 3; // fake up to 3 pages
      _currentPage++;

    } catch (e) {
      _error = "Lỗi khi tải lịch sử: $e";
    } finally {
      if (_isLoading) _isLoading = false;
      if (_isLoadingMore) _isLoadingMore = false;
      notifyListeners();
    }
  }

  void changeRange(String profileId, String newRange) {
    if (newRange == _currentRange) return;
    fetchHistory(profileId: profileId, range: newRange, refresh: true);
  }

  void loadMore(String profileId) {
    if (_hasMore && !_isLoading && !_isLoadingMore) {
      fetchHistory(profileId: profileId, range: _currentRange, refresh: false);
    }
  }
}
