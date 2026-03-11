import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';

class SleepProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  SleepSession? _latestSession;
  bool _isLoading = false;
  String? _errorMessage;

  SleepSession? get latestSession => _latestSession;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchLatestSleep({String? patientId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiEndpoints.latestSleep);
      _latestSession = SleepSession.fromJson(response);
    } catch (e) {
      _errorMessage = 'Khong the tai du lieu giac ngu: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
