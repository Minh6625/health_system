import 'package:flutter/foundation.dart';

import '../models/health_report.dart';
import '../repositories/monitoring_repository.dart';

enum HealthReportUIState { initial, loading, success, error }

/// Loads `/metrics/health-report` once per screen open. No polling — the
/// payload is a 24-hour aggregate, refreshing on pull-to-refresh is enough.
class HealthReportProvider extends ChangeNotifier {
  HealthReportProvider({
    MonitoringRepository? repository,
    String? profileId,
  }) : _repository = repository ?? MonitoringRepository(),
       _profileId = profileId;

  final MonitoringRepository _repository;
  final String? _profileId;

  HealthReportUIState _state = HealthReportUIState.initial;
  HealthReportUIState get state => _state;

  HealthReport? _report;
  HealthReport? get report => _report;

  String? _error;
  String? get error => _error;

  bool _isFetching = false;
  bool _disposed = false;

  Future<void> load() => _fetch(showLoading: true);

  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_disposed || _isFetching) return;
    _isFetching = true;

    if (showLoading || _state == HealthReportUIState.initial) {
      _state = HealthReportUIState.loading;
      _error = null;
      notifyListeners();
    }

    try {
      final report = await _repository.getHealthReport(profileId: _profileId);
      if (_disposed) return;
      _report = report;
      _state = HealthReportUIState.success;
      _error = null;
    } catch (e) {
      if (_disposed) return;
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = HealthReportUIState.error;
    } finally {
      _isFetching = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
