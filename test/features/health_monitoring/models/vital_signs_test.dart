import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/health_monitoring/models/vital_signs.dart';

void main() {
  group('vital classification helpers', () {
    test(
      'SpO2 thresholds stay consistent for home cards and detail screen',
      () {
        expect(classifySpo2Status(91), VitalStatus.critical);
        expect(classifySpo2Status(93), VitalStatus.warning);
        expect(classifySpo2Status(98), VitalStatus.normal);
      },
    );

    test(
      'temperature thresholds stay consistent for home cards and detail screen',
      () {
        expect(classifyTemperatureStatus(35.4), VitalStatus.critical);
        expect(classifyTemperatureStatus(35.8), VitalStatus.warning);
        expect(classifyTemperatureStatus(36.7), VitalStatus.normal);
        expect(classifyTemperatureStatus(37.9), VitalStatus.critical);
      },
    );

    test(
      'blood pressure thresholds combine systolic and diastolic severity',
      () {
        expect(
          classifyBloodPressureStatus(systolic: 142, diastolic: 84),
          VitalStatus.critical,
        );
        expect(
          classifyBloodPressureStatus(systolic: 128, diastolic: 84),
          VitalStatus.warning,
        );
        expect(
          classifyBloodPressureStatus(systolic: 118, diastolic: 76),
          VitalStatus.normal,
        );
      },
    );
  });

  test('VitalSigns model methods reuse the shared classification helpers', () {
    final vitals = VitalSigns(
      heartRate: 108,
      spo2: 93,
      temperature: 37.4,
      respiratoryRate: 22,
      bloodPressureSys: 128,
      bloodPressureDia: 84,
      timestamp: DateTime.utc(2026, 4, 19, 8),
    );

    expect(vitals.getHeartRateStatus(), classifyHeartRateStatus(108));
    expect(vitals.getSpo2Status(), classifySpo2Status(93));
    expect(vitals.getTemperatureStatus(), classifyTemperatureStatus(37.4));
    expect(
      classifyBloodPressureStatus(
        systolic: vitals.bloodPressureSys,
        diastolic: vitals.bloodPressureDia,
      ),
      VitalStatus.warning,
    );
    expect(
      vitals.getRespiratoryRateStatus(),
      classifyRespiratoryRateStatus(22),
    );
  });
}
