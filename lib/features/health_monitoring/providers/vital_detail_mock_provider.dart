import 'package:flutter/material.dart';
import '../models/vital_signs.dart'; // Ensure VitalStatus is available here

enum VitalDetailUIState {
  loading,
  success,
  empty,
  invalid,
  error,
}

class VitalDetailMockProvider extends ChangeNotifier {
  VitalDetailUIState _state = VitalDetailUIState.loading;
  VitalDetailUIState get state => _state;

  String _vitalType = 'hr';
  String? _profileId;
  String get vitalType => _vitalType;
  String? get profileId => _profileId;
  bool get isSelf => _profileId == null;

  String _title = '';
  String _value = '--';
  String _unit = '';
  VitalStatus _status = VitalStatus.unknown;
  List<List<double>> _chartData = [];
  List<Color> _chartColors = [];
  String _educationText = '';
  String _linkedProfileName = '';

  String get title => _title;
  String get value => _value;
  String get unit => _unit;
  VitalStatus get vitalStatus => _status;
  List<List<double>> get chartData => _chartData;
  List<Color> get chartColors => _chartColors;
  String get educationText => _educationText;
  String get linkedProfileName => _linkedProfileName;

  void loadDetail(String type, String? id) async {
    _vitalType = type;
    _profileId = id;
    _state = VitalDetailUIState.loading;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    if (id != null) {
      _linkedProfileName = 'Ông Nguyễn Văn A'; // Mock name
    } else {
      _linkedProfileName = '';
    }

    // Default setups
    switch (type) {
      case 'hr':
        _title = 'Nhịp tim';
        _unit = 'BPM';
        _chartColors = [Colors.red.shade700];
        _educationText = 'Nhịp tim bình thường của người lớn lúc nghỉ ngơi là từ 60 đến 100 nhịp mỗi phút. Nhịp tim có thể thay đổi tùy thuộc vào hoạt động, cảm xúc và tình trạng sức khỏe.';
        break;
      case 'spo2':
        _title = 'SpO₂';
        _unit = '%';
        _chartColors = [Colors.blue.shade700];
        _educationText = 'Độ bão hòa oxy trong máu (SpO₂) bình thường là từ 95% đến 100%. Dưới 90% được xem là thấp và cần được theo dõi y tế.';
        break;
      case 'bp':
        _title = 'Huyết áp';
        _unit = 'mmHg';
        _chartColors = [Colors.purple.shade700, Colors.deepPurple.shade300];
        _educationText = 'Huyết áp lý tưởng cho người lớn thường dưới 120/80 mmHg. Tăng huyết áp có thể làm tăng nguy cơ mắc bệnh tim mạch và đột quỵ.';
        break;
      case 'temp':
        _title = 'Nhiệt độ';
        _unit = '°C';
        _chartColors = [Colors.orange.shade700];
        _educationText = 'Nhiệt độ cơ thể bình thường dao động từ 36.1°C đến 37.2°C. Sốt nhẹ bắt đầu từ 37.8°C trở lên.';
        break;
      default:
        _title = 'Chỉ số';
        _unit = '';
        _chartColors = [Colors.grey.shade700];
        _educationText = '--';
    }

    // Determine state based on a mock logic combining type and id
    // We will use profileId to simulate different states for preview purposes.
    if (id == 'empty') {
      _state = VitalDetailUIState.empty;
      _value = type == 'hr' ? '72' : type == 'spo2' ? '98' : type == 'temp' ? '36.5' : '120/80';
      _status = VitalStatus.normal;
      _chartData = [];
    } else if (id == 'invalid') {
      _state = VitalDetailUIState.invalid;
      _value = '--';
      _status = VitalStatus.unknown;
    } else if (id == 'error') {
      _state = VitalDetailUIState.error;
    } else if (id == 'critical_linked') {
      _state = VitalDetailUIState.success;
      _value = type == 'hr' ? '140' : type == 'spo2' ? '88' : type == 'temp' ? '39.5' : '160/100';
      _status = VitalStatus.critical;
      _chartData = _generateMockChart(type, true);
    } else if (id == 'critical') {
      // self critical
      _profileId = null; // simulate self
      _state = VitalDetailUIState.success;
      _value = type == 'hr' ? '45' : type == 'spo2' ? '91' : type == 'temp' ? '40.0' : '180/110';
      _status = VitalStatus.critical;
      _chartData = _generateMockChart(type, true);
    } else {
      // normal success
      _state = VitalDetailUIState.success;
      _value = type == 'hr' ? '75' : type == 'spo2' ? '97' : type == 'temp' ? '36.8' : '115/75';
      _status = VitalStatus.normal;
      _chartData = _generateMockChart(type, false);
    }

    notifyListeners();
  }

  List<List<double>> _generateMockChart(String type, bool isCritical) {
    if (type == 'bp') {
      if (isCritical) {
        return [
          [130, 135, 140, 150, 160, 170, 175, 180], // Sys
          [85, 90, 95, 100, 105, 108, 110, 110],  // Dia
        ];
      }
      return [
        [115, 118, 120, 115, 122, 119, 117, 115], // Sys
        [75, 76, 78, 75, 79, 78, 76, 75],         // Dia
      ];
    } else if (type == 'temp') {
      if (isCritical) {
        return [[36.8, 37.2, 37.5, 38.0, 38.5, 39.2, 39.8, 40.0]];
      }
      return [[36.5, 36.6, 36.5, 36.7, 36.8, 36.7, 36.6, 36.8]];
    } else if (type == 'spo2') {
       if (isCritical) {
         return [[97, 96, 95, 94, 93, 91, 90, 88]];
       }
       return [[97, 98, 97, 99, 98, 97, 98, 97]];
    } else {
       if (isCritical) {
         return [[70, 75, 80, 100, 120, 130, 135, 140]];
       }
       return [[68, 72, 75, 70, 74, 73, 75, 75]];
    }
  }
}
