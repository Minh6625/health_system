import 'dart:async';

import 'package:flutter/material.dart';

import '../../../health_monitoring/models/vital_signs.dart';
import '../../../health_monitoring/providers/vital_signs_provider.dart';
import '../../../health_monitoring/repositories/monitoring_repository.dart';

class HomeDashboardProvider extends ChangeNotifier {
  HomeDashboardProvider({
    MonitoringRepository? repository,
    Duration pollInterval = const Duration(seconds: 5),
  })  : _repository = repository ?? MonitoringRepository(),
        _pollInterval = pollInterval;

  final MonitoringRepository _repository;
  final Duration _pollInterval;

  VitalsUIState _state = VitalsUIState.initial;
  VitalsUIState get state => _state;

  VitalSigns? _vitals;
  VitalSigns? get vitals => _vitals;

  String? _error;
  String? get error => _error;

  Timer? _timer;
  bool _polling = false;
  bool _isFetching = false;
  bool _disposed = false;

  void startPolling() {
    if (_polling || _disposed) {
      return;
    }
    _polling = true;
    _fetch(showLoading: _vitals == null);
    _timer = Timer.periodic(
      _pollInterval,
      (_) => _fetch(showLoading: false),
    );
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
  }

  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_disposed || _isFetching) {
      return;
    }

    _isFetching = true;

    if ((showLoading && _vitals == null) || _state == VitalsUIState.initial) {
      _state = VitalsUIState.loading;
      if (!_disposed) {
        notifyListeners();
      }
    }

    try {
      final result = await _repository.getLatestVitals();
      if (_disposed) {
        return;
      }
      _vitals = result;
      _error = null;
      _state = _isVitalsEmpty(result)
          ? VitalsUIState.empty
          : VitalsUIState.success;
    } catch (e) {
      if (_disposed) {
        return;
      }
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = VitalsUIState.error;
    } finally {
      _isFetching = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  bool _isVitalsEmpty(VitalSigns vitals) {
    return vitals.heartRate == null &&
        vitals.spo2 == null &&
        vitals.temperature == null &&
        vitals.respiratoryRate == null &&
        vitals.bloodPressureSys == null &&
        vitals.bloodPressureDia == null;
  }

  @override
  void dispose() {
    stopPolling();
    _disposed = true;
    super.dispose();
  }
}
