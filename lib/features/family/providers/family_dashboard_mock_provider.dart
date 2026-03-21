import 'package:flutter/foundation.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';
import 'package:healthguard/features/family/providers/shared_family_mock_provider.dart';

enum FamilyFilter { all, sos, attention, priority }

class FamilyDashboardMockProvider extends ChangeNotifier {
  bool _isLoading = true;
  String? _error;
  FamilyFilter _currentFilter = FamilyFilter.all;

  FamilyDashboardMockProvider() {
    SharedFamilyMockProvider().addListener(_onGlobalChange);
  }

  void _onGlobalChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    SharedFamilyMockProvider().removeListener(_onGlobalChange);
    super.dispose();
  }

  List<FamilyProfileSnapshot> get _profiles => SharedFamilyMockProvider().generateDashboardSnapshots();

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

  int get totalTracked => _profiles.isNotEmpty ? _profiles.where((p) => p.hasViewVitalsPermission).length : 0;
  int get stableCount => _profiles.where((p) => p.riskLevel == 'low' && !p.isSosActive && p.hasViewVitalsPermission).length;
  int get attentionCount => _profiles.where((p) => (p.riskLevel == 'medium' || p.riskLevel == 'high') && !p.isSosActive && p.hasViewVitalsPermission).length;
  int get sosCount => _profiles.where((p) => p.isSosActive).length;

  List<FamilyProfileSnapshot> get displayList {
    // Sort logic: SOS first -> High risk -> Medium risk -> Low risk
    var list = List<FamilyProfileSnapshot>.from(_profiles);
    list.sort((a, b) {
      if (a.isSosActive && !b.isSosActive) return -1;
      if (!a.isSosActive && b.isSosActive) return 1;

      // Risk weight
      int riskWeight(String r) {
        if (r == 'high') return 3;
        if (r == 'medium') return 2;
        return 1;
      }
      return riskWeight(b.riskLevel).compareTo(riskWeight(a.riskLevel));
    });

    if (_currentFilter == FamilyFilter.sos) {
      list = list.where((p) => p.isSosActive).toList();
    } else if (_currentFilter == FamilyFilter.attention) {
      list = list.where((p) => p.riskLevel == 'medium' || p.riskLevel == 'high').toList();
    } else if (_currentFilter == FamilyFilter.priority) {
      list = list.where((p) => p.isPinned).toList();
    }

    return list;
  }

  void loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Trigger global load if not already loaded
    await SharedFamilyMockProvider().loadInitialData();

    _isLoading = false;
    notifyListeners();
  }
}
