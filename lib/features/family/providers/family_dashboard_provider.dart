import "package:flutter/foundation.dart";
import "package:healthguard/features/family/models/family_profile_snapshot.dart";
import "package:healthguard/features/family/repositories/family_repository.dart";

enum FamilyFilter { all, sos, attention, priority }

class FamilyDashboardProvider extends ChangeNotifier {
  final FamilyRepository _repository = FamilyRepository();
  bool _isLoading = true;
  String? _error;
  FamilyFilter _currentFilter = FamilyFilter.all;

  List<FamilyProfileSnapshot> _profiles = [];

  List<FamilyProfileSnapshot> get profiles => _profiles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  FamilyFilter get currentFilter => _currentFilter;

  void setFilter(FamilyFilter filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      notifyListeners();
    }
  }

  int get totalTracked => _profiles.isNotEmpty
      ? _profiles.where((p) => p.hasViewVitalsPermission).length
      : 0;
  int get stableCount => _profiles
      .where(
        (p) =>
            p.hasVitalsData &&
            p.riskLevel == "low" &&
            !p.isSosActive &&
            p.hasViewVitalsPermission,
      )
      .length;
  int get attentionCount => _profiles
      .where(
        (p) =>
            p.hasVitalsData &&
            (p.riskLevel == "medium" || p.riskLevel == "high") &&
            !p.isSosActive &&
            p.hasViewVitalsPermission,
      )
      .length;
  int get sosCount => _profiles.where((p) => p.isSosActive).length;
  int get trackingAlertCount => _profiles
      .where(
        (p) =>
            p.hasViewVitalsPermission &&
            (p.isSosActive ||
                (p.hasVitalsData &&
                    (p.riskLevel == "medium" || p.riskLevel == "high"))),
      )
      .length;

  List<FamilyProfileSnapshot> get displayList {
    var list = List<FamilyProfileSnapshot>.from(_profiles);
    list.sort((a, b) {
      if (a.isSosActive && !b.isSosActive) return -1;
      if (!a.isSosActive && b.isSosActive) return 1;

      int riskWeight(String r) {
        if (r == "high") return 3;
        if (r == "medium") return 2;
        return 1;
      }

      return riskWeight(b.riskLevel).compareTo(riskWeight(a.riskLevel));
    });

    if (_currentFilter == FamilyFilter.sos) {
      list = list.where((p) => p.isSosActive).toList();
    } else if (_currentFilter == FamilyFilter.attention) {
      list = list
          .where((p) => p.riskLevel == "medium" || p.riskLevel == "high")
          .toList();
    } else if (_currentFilter == FamilyFilter.priority) {
      list = list.where((p) => p.isPinned).toList();
    }

    return list;
  }

  Future<void> loadDashboard(int currentUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profiles = await _repository.getFamilyDashboard();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
