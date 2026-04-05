import 'package:flutter/material.dart';
import '../repositories/home_dashboard_repository.dart';

class HomeDashboardProvider extends ChangeNotifier {
  final HomeDashboardRepository _repository = HomeDashboardRepository();

  bool _isLoading = false;
  String? _error;

  // Vital signs data
  double? _heartRate;
  double? _spo2;
  double? _temperature;
  double? _respiratoryRate;
  double? _bloodPressureSys;
  double? _bloodPressureDia;
  DateTime? _vitalsTimestamp;
  bool _vitalsStale = false;

  // Health report data
  Map<String, dynamic> _vitals24hAvg = {};
  double? _latestRiskScore;
  String? _riskLevel;
  String? _riskType;
  DateTime? _lastUpdated;

  // Sleep data
  Map<String, dynamic>? _sleepData;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  double? get heartRate => _heartRate;
  double? get spo2 => _spo2;
  double? get temperature => _temperature;
  double? get respiratoryRate => _respiratoryRate;
  double? get bloodPressureSys => _bloodPressureSys;
  double? get bloodPressureDia => _bloodPressureDia;
  DateTime? get vitalsTimestamp => _vitalsTimestamp;
  bool get vitalsStale => _vitalsStale;

  Map<String, dynamic> get vitals24hAvg => _vitals24hAvg;
  double? get latestRiskScore => _latestRiskScore;
  String? get riskLevel => _riskLevel;
  String? get riskType => _riskType;
  DateTime? get lastUpdated => _lastUpdated;

  Map<String, dynamic>? get sleepData => _sleepData;

  /// Load all dashboard data from API
  Future<void> loadDashboardData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Fetch all data in parallel
      await Future.wait([
        _fetchLatestVitals(),
        _fetchHealthReport(),
        _fetchLatestSleep(),
      ], eagerError: false);
    } catch (e) {
      _error = 'Không thể tải dữ liệu: $e';
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> _fetchLatestVitals() async {
    try {
      final vitals = await _repository.getLatestVitalSigns();
      _heartRate = vitals.heartRate;
      _spo2 = vitals.spo2;
      _temperature = vitals.temperature;
      _respiratoryRate = vitals.respiratoryRate;
      _bloodPressureSys = vitals.bloodPressureSys;
      _bloodPressureDia = vitals.bloodPressureDia;
      _vitalsTimestamp = vitals.timestamp;
      _vitalsStale = vitals.isStale;
    } catch (e) {
      debugPrint('Error fetching vitals: $e');
    }
  }

  Future<void> _fetchHealthReport() async {
    try {
      final report = await _repository.getHealthReport();
      _vitals24hAvg = report.vitals24hAvg;
      _latestRiskScore = report.latestRiskScore;
      _riskLevel = report.riskLevel;
      _riskType = report.riskType;
      _lastUpdated = report.lastUpdated;
    } catch (e) {
      debugPrint('Error fetching health report: $e');
    }
  }

  Future<void> _fetchLatestSleep() async {
    try {
      _sleepData = await _repository.getLatestSleepSession();
    } catch (e) {
      debugPrint('Error fetching sleep data: $e');
    }
  }

  /// Refresh all data (for pull-to-refresh)
  Future<void> refreshDashboard() async {
    await loadDashboardData();
  }
}
