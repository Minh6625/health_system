import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vital_signs.dart';
import '../models/vitals_timeseries.dart';
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

  // F-8 (M-9): expose the backend's `is_stale` flag so the screen can render
  // a "Thiết bị mất kết nối" sub-message instead of the previous lie
  // where the last-seen reading was painted as if it were live. Backend
  // already ships `is_stale=true` after VITALS_STALE_AFTER (5 min) of no
  // ingest — the frontend was simply ignoring the field.
  bool get isStale => _vitals?.isStale ?? false;

  String? _error;
  String? get error => _error;

  // F-12 (M-6): cached 24h time-series the chart on
  // `vital_detail_screen.dart` reads via [chartData]. Defaults to the
  // empty envelope so the screen renders the "no data" placeholder
  // before the first fetch completes instead of throwing on a null.
  VitalsTimeseries _timeseries = VitalsTimeseries.empty;
  VitalsTimeseries get timeseries => _timeseries;

  // Loaded once when polling starts (and on pull-to-refresh). We do
  // NOT refresh the time-series on every 5 s tick — that would re-run
  // a 24 h aggregate query against TimescaleDB for marginal value, and
  // the chart axis is bucketed at 15 min so sub-bucket changes wouldn't
  // even be visible. The latest-vitals poll keeps the live tile fresh.
  bool _hasLoadedTimeseries = false;
  bool _isLoadingTimeseries = false;
  bool get isLoadingTimeseries => _isLoadingTimeseries;

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

  /// F-12 (M-6): chart Y-values for the current vital channel, sourced
  /// from the cached [VitalsTimeseries] envelope. Returns `const []`
  /// when nothing has been fetched yet or the response is empty so the
  /// existing "Chưa có dữ liệu xu hướng" placeholder kicks in.
  ///
  /// Pre-fix this returned `const []` unconditionally because no
  /// endpoint produced time-series data — the screen always fell
  /// through to the placeholder regardless of whether the device was
  /// actively streaming.
  ///
  /// Channel-level nulls are dropped (rather than treated as zero)
  /// because the underlying [MiniLineChart] consumes
  /// `List<List<double>>` and a zero would render as a misleading
  /// "vital flatlined" cliff. For BP we drop a bucket only when both
  /// sys and dia are null so the two lines stay time-aligned.
  List<List<double>> get chartData {
    final points = _timeseries.data;
    if (points.isEmpty) return const [];

    switch (_vitalType) {
      case 'hr':
        final ys = <double>[];
        for (final p in points) {
          if (p.heartRate != null) ys.add(p.heartRate!);
        }
        return ys.isEmpty ? const [] : [ys];
      case 'spo2':
        final ys = <double>[];
        for (final p in points) {
          if (p.spo2 != null) ys.add(p.spo2!);
        }
        return ys.isEmpty ? const [] : [ys];
      case 'bp':
        final sys = <double>[];
        final dia = <double>[];
        for (final p in points) {
          if (p.bloodPressureSys != null && p.bloodPressureDia != null) {
            sys.add(p.bloodPressureSys!);
            dia.add(p.bloodPressureDia!);
          }
        }
        return sys.isEmpty ? const [] : [sys, dia];
      case 'temp':
        final ys = <double>[];
        for (final p in points) {
          if (p.temperature != null) ys.add(p.temperature!);
        }
        return ys.isEmpty ? const [] : [ys];
      case 'rr':
        final ys = <double>[];
        for (final p in points) {
          if (p.respiratoryRate != null) ys.add(p.respiratoryRate!);
        }
        return ys.isEmpty ? const [] : [ys];
      default:
        return const [];
    }
  }

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
    // F-12 (M-6): kick off the chart fetch alongside the live tile.
    // Fire-and-forget — the chart placeholder is already on screen so
    // a slow time-series fetch doesn't block the live values.
    if (!_hasLoadedTimeseries) {
      // ignore: discarded_futures — the result is consumed via notifyListeners.
      loadTimeseries();
    }
    _timer = Timer.periodic(_pollInterval, (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
  }

  Future<void> refresh() {
    // F-12 (M-6): pull-to-refresh refreshes both the live tile AND the
    // chart so the user gets a visibly updated chart axis after pulling.
    // ignore: discarded_futures — chart fetch runs in parallel.
    loadTimeseries(force: true);
    return _fetch(showLoading: true);
  }

  /// F-12 (M-6): fetch the 24h time-series envelope for the chart.
  ///
  /// Idempotent unless [force] is true, so the screen can call this
  /// from `initState`/listeners without double-firing. Errors are
  /// swallowed into a notifyListeners()-flushed log: the chart is a
  /// secondary surface (the live tile still renders), and 500-ing the
  /// whole screen because the chart endpoint hiccuped would be a worse
  /// UX than just showing the placeholder.
  Future<void> loadTimeseries({bool force = false}) async {
    if (_disposed) return;
    if (_isLoadingTimeseries) return;
    if (_hasLoadedTimeseries && !force) return;

    _isLoadingTimeseries = true;
    if (!_disposed) notifyListeners();

    try {
      final result = await _repo.getVitalsTimeseries(profileId: _profileId);
      if (_disposed) return;
      _timeseries = result;
      _hasLoadedTimeseries = true;
    } catch (_) {
      if (_disposed) return;
      // Keep _hasLoadedTimeseries=false so a later startPolling()/refresh
      // can retry. We deliberately do not surface a separate chart
      // error UI: the placeholder already covers the empty case and the
      // live tile is the primary signal on this screen.
      _timeseries = VitalsTimeseries.empty;
    } finally {
      _isLoadingTimeseries = false;
      if (!_disposed) notifyListeners();
    }
  }

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
    // F-8 (M-9): treat stale snapshots like an empty payload so the UI
    // renders the "no data" branch instead of painting yesterday's number
    // as if it were live. The screen layer differentiates "stale" from
    // "never had data" via `provider.isStale` to choose the sub-message.
    if (vitals.isStale) {
      return true;
    }
    return vitals.heartRate == null &&
        vitals.spo2 == null &&
        vitals.temperature == null &&
        vitals.respiratoryRate == null &&
        vitals.bloodPressureSys == null &&
        vitals.bloodPressureDia == null;
  }

  String extractValue(String vitalType) {
    // F-8 (M-9): refuse to surface stale numbers — a watch that hasn't sent
    // data for 5+ minutes must not be displayed as if it were still
    // streaming. Falls through to the same "--" / "--/--" placeholder the
    // null-vitals branch already uses, so callers don't need a separate
    // code path.
    if (_vitals == null || _vitals!.isStale) {
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
    // F-8 (M-9): a stale snapshot must not classify as normal/warning/critical.
    // The status pill drives both color and the SOS button decision below;
    // letting a stale reading look "critical" would either trigger a
    // false-positive SOS suggestion or paint a false-negative "normal"
    // banner. Force `unknown` so the UI defers to the offline messaging.
    if (_vitals == null || _vitals!.isStale) {
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
