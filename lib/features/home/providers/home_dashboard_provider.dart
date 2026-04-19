import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../repositories/home_dashboard_repository.dart';

enum HomeDashboardSection { vitals, healthReport, sleep }

class HomeDashboardProvider extends ChangeNotifier {
  HomeDashboardProvider({
    HomeDashboardRepository? repository,
    String? profileId,
  }) : _repository = repository ?? HomeDashboardRepository(),
       _profileId = _normalizeProfileId(profileId);

  final HomeDashboardRepository _repository;

  bool _isLoading = false;
  String? _error;
  String? _profileId;
  final Map<HomeDashboardSection, String> _sectionErrors = {};

  double? _heartRate;
  double? _spo2;
  double? _temperature;
  double? _respiratoryRate;
  double? _bloodPressureSys;
  double? _bloodPressureDia;
  DateTime? _vitalsTimestamp;
  bool _vitalsStale = false;

  Map<String, dynamic> _vitals24hAvg = {};
  double? _latestRiskScore;
  double? _healthScore;
  String? _healthLevel;
  String? _healthSummary;
  String? _riskLevel;
  String? _riskType;
  DateTime? _lastUpdated;
  double? _riskConfidence;
  bool _reportStale = true;

  Map<String, dynamic>? _sleepData;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get profileId => _profileId;
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
  double? get healthScore => _healthScore;
  String? get healthLevel => _healthLevel;
  String? get healthSummary => _healthSummary;
  String? get riskLevel => _riskLevel;
  String? get riskType => _riskType;
  DateTime? get lastUpdated => _lastUpdated;
  double? get riskConfidence => _riskConfidence;
  bool get reportStale => _reportStale;
  Map<String, dynamic>? get sleepData => _sleepData;
  bool get hasSectionErrors => _sectionErrors.isNotEmpty;
  Map<HomeDashboardSection, String> get sectionErrors =>
      Map.unmodifiable(_sectionErrors);
  String? get sectionErrorMessage {
    if (_sectionErrors.isEmpty) {
      return null;
    }
    final failedSections = _sectionErrors.keys
        .map(_sectionLabel)
        .toList(growable: false);
    return 'Một phần dữ liệu chưa tải được: ${failedSections.join(', ')}.';
  }

  DateTime? get latestDashboardTimestamp {
    if (_vitalsTimestamp == null) {
      return _lastUpdated;
    }
    if (_lastUpdated == null) {
      return _vitalsTimestamp;
    }
    return _vitalsTimestamp!.isAfter(_lastUpdated!)
        ? _vitalsTimestamp
        : _lastUpdated;
  }

  static String? _normalizeProfileId(String? profileId) {
    if (profileId == null || profileId.isEmpty || profileId == 'self') {
      return null;
    }
    return profileId;
  }

  static String _sectionLabel(HomeDashboardSection section) {
    switch (section) {
      case HomeDashboardSection.vitals:
        return 'chỉ số sinh tồn';
      case HomeDashboardSection.healthReport:
        return 'điểm sức khỏe';
      case HomeDashboardSection.sleep:
        return 'giấc ngủ';
    }
  }

  void configureProfile(String? profileId) {
    final normalizedProfileId = _normalizeProfileId(profileId);
    if (normalizedProfileId == _profileId) {
      return;
    }
    _profileId = normalizedProfileId;
  }

  Future<void> loadDashboardData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    _sectionErrors.clear();

    try {
      await Future.wait([
        _fetchLatestVitals(),
        _fetchHealthReport(),
        _fetchLatestSleep(),
      ], eagerError: false);
      _error = _sectionErrors.length == HomeDashboardSection.values.length
          ? sectionErrorMessage
          : null;
    } catch (error) {
      _error = 'Không thể tải dữ liệu: $error';
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> _fetchLatestVitals() async {
    try {
      final vitals = await _repository.getLatestVitalSigns(
        profileId: _profileId,
      );
      _heartRate = vitals.heartRate;
      _spo2 = vitals.spo2;
      _temperature = vitals.temperature;
      _respiratoryRate = vitals.respiratoryRate;
      _bloodPressureSys = vitals.bloodPressureSys;
      _bloodPressureDia = vitals.bloodPressureDia;
      _vitalsTimestamp = vitals.timestamp;
      _vitalsStale = vitals.isStale;
    } catch (error) {
      _recordSectionError(HomeDashboardSection.vitals, error);
    }
  }

  Future<void> _fetchHealthReport() async {
    try {
      final report = await _repository.getHealthReport(profileId: _profileId);
      final latestRiskScore = report.latestRiskScore;
      final fallbackHealthScore = latestRiskScore != null
          ? (100 - latestRiskScore).clamp(0, 100).toDouble()
          : null;
      _vitals24hAvg = report.vitals24hAvg;
      _latestRiskScore = latestRiskScore;
      _healthScore = report.healthScore ?? fallbackHealthScore;
      _healthLevel = report.healthLevel;
      _healthSummary = report.healthSummary;
      _riskLevel = report.riskLevel;
      _riskType = report.riskType;
      _lastUpdated = report.lastUpdated;
      _riskConfidence = report.confidence;
      _reportStale = report.isStale;
    } catch (error) {
      _recordSectionError(HomeDashboardSection.healthReport, error);
    }
  }

  Future<void> _fetchLatestSleep() async {
    try {
      _sleepData = await _repository.getLatestSleepSession(
        profileId: _profileId,
      );
    } catch (error) {
      _recordSectionError(HomeDashboardSection.sleep, error);
    }
  }

  void _recordSectionError(HomeDashboardSection section, Object error) {
    _sectionErrors[section] = error.toString();
    debugPrint(
      'Home dashboard failed to load ${_sectionLabel(section)} for profile '
      '${_profileId ?? 'self'}: $error',
    );
  }

  Future<void> refreshDashboard() async {
    await loadDashboardData();
  }
}
