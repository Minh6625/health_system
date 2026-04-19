import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vital_signs.dart';
import '../repositories/monitoring_repository.dart';

enum VitalsUIState { initial, loading, success, error, empty }

class VitalSignsProvider extends ChangeNotifier {
  final MonitoringRepository _repo;
  final Duration _pollInterval;
  final String _vitalType;
  final String? _profileId;

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

  VitalSignsProvider({
    MonitoringRepository? repo,
    Duration pollInterval = const Duration(seconds: 5),
    required String vitalType,
    String? profileId,
  }) : _repo = repo ?? MonitoringRepository(),
       _pollInterval = pollInterval,
       _vitalType = vitalType,
       _profileId = profileId;

  String get title => switch (_vitalType) {
    'hr' => 'Nhịp tim',
    'spo2' => 'SpO₂',
    'bp' => 'Huyết áp',
    'temp' => 'Nhiệt độ',
    'rr' => 'Nhịp thở',
    _ => 'Chi tiết chỉ số',
  };

  String get unit => switch (_vitalType) {
    'hr' => 'BPM',
    'spo2' => '%',
    'bp' => 'mmHg',
    'temp' => '°C',
    'rr' => 'lần/phút',
    _ => '',
  };

  String get value => extractValue(_vitalType);

  VitalStatus get vitalStatus => extractStatus(_vitalType);

  List<List<double>> get chartData => const [];

  List<Color> get chartColors => switch (_vitalType) {
    'hr' => [Colors.red.shade700],
    'spo2' => [Colors.blue.shade700],
    'bp' => [Colors.purple.shade700, Colors.deepPurple.shade300],
    'temp' => [Colors.orange.shade700],
    'rr' => [Colors.teal.shade700],
    _ => [Colors.grey.shade700],
  };

  String get educationText => switch (_vitalType) {
    'hr' =>
      'Nhịp tim bình thường của người lớn lúc nghỉ ngơi là từ 60 đến 100 nhịp mỗi phút. Nhịp tim có thể thay đổi tùy thuộc vào hoạt động, cảm xúc và tình trạng sức khỏe.',
    'spo2' =>
      'Độ bão hòa oxy trong máu (SpO₂) bình thường là từ 95% đến 100%. Dưới 90% được xem là thấp và cần được theo dõi y tế.',
    'bp' =>
      'Huyết áp lý tưởng cho người lớn thường dưới 120/80 mmHg. Tăng huyết áp có thể làm tăng nguy cơ mắc bệnh tim mạch và đột quỵ.',
    'temp' =>
      'Nhiệt độ cơ thể bình thường dao động từ 36.1°C đến 37.2°C. Sốt nhẹ bắt đầu từ 37.8°C trở lên.',
    'rr' =>
      'Nhịp thở bình thường của người lớn thường nằm trong khoảng 12 đến 20 lần mỗi phút. Nhịp thở quá nhanh hoặc quá chậm cần được theo dõi thêm.',
    _ => '--',
  };

  String get linkedProfileName => _profileId == null ? '' : 'Hồ sơ liên kết';

  bool get isSelf => _profileId == null;

  void startPolling() {
    if (_polling || _disposed) {
      return;
    }
    _polling = true;
    _fetch(showLoading: true);
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
  }

  Future<void> refresh() => _fetch(showLoading: true);

  Future<void> _fetch({bool showLoading = false}) async {
    if (_disposed || _isFetching) {
      return;
    }

    _isFetching = true;

    if (showLoading || _state == VitalsUIState.initial) {
      _state = VitalsUIState.loading;
      if (!_disposed) {
        notifyListeners();
      }
    }

    try {
      final result = await _repo.getLatestVitals(profileId: _profileId);
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

  String extractValue(String vitalType) {
    if (_vitals == null) {
      return vitalType == 'bp' ? '--/--' : '--';
    }

    switch (vitalType) {
      case 'hr':
        return _vitals!.heartRate?.toStringAsFixed(0) ?? '--';
      case 'spo2':
        return _vitals!.spo2?.toStringAsFixed(1) ?? '--';
      case 'temp':
        return _vitals!.temperature?.toStringAsFixed(1) ?? '--';
      case 'bp':
        final sys = _vitals!.bloodPressureSys?.toStringAsFixed(0) ?? '--';
        final dia = _vitals!.bloodPressureDia?.toStringAsFixed(0) ?? '--';
        return '$sys/$dia';
      case 'rr':
        return _vitals!.respiratoryRate?.toStringAsFixed(0) ?? '--';
      default:
        return '--';
    }
  }

  VitalStatus extractStatus(String vitalType) {
    if (_vitals == null) {
      return VitalStatus.unknown;
    }

    switch (vitalType) {
      case 'hr':
        return _vitals!.getHeartRateStatus();
      case 'spo2':
        return _vitals!.getSpo2Status();
      case 'temp':
        return _vitals!.getTemperatureStatus();
      case 'bp':
        return classifyBloodPressureStatus(
          systolic: _vitals!.bloodPressureSys,
          diastolic: _vitals!.bloodPressureDia,
        );
      case 'rr':
        return _vitals!.getRespiratoryRateStatus();
      default:
        return VitalStatus.unknown;
    }
  }

  @override
  void dispose() {
    stopPolling();
    _disposed = true;
    super.dispose();
  }
}
