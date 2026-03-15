import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/core/network/api_client.dart';
import '../models/vital_signs.dart';

class VitalSignsProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  VitalSigns? _currentVitals;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _autoRefreshTimer;

  VitalSigns? get currentVitals => _currentVitals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchLatestVitals({String? patientId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('/vital-signs/latest');

      _currentVitals = VitalSigns.fromJson(response);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Không thể tải dữ liệu: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Auto-refresh every 5 seconds as per UC006 requirement
  void startAutoRefresh({String? patientId}) {
    stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => fetchLatestVitals(patientId: patientId),
    );
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
