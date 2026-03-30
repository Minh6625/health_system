import 'package:flutter/material.dart';
import '../models/vital_signs.dart';
import 'animated_vital_value.dart';

/// A wide, full-width card showing Blood Pressure (Systolic / Diastolic).
/// Status color (green/orange/red/grey) mirrors [VitalCard] logic.
/// Value numbers animate with [AnimatedVitalValue] on every data update.
class BloodPressureCard extends StatelessWidget {
  final VitalSigns vitals;
  final VoidCallback? onTap;

  const BloodPressureCard({super.key, required this.vitals, this.onTap});

  Color _bgColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => Colors.green.shade50,
        VitalStatus.warning => Colors.orange.shade50,
        VitalStatus.critical => Colors.red.shade50,
        VitalStatus.unknown => Colors.grey.shade50,
      };

  Color _borderColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => Colors.green.shade200,
        VitalStatus.warning => Colors.orange.shade300,
        VitalStatus.critical => Colors.red.shade300,
        VitalStatus.unknown => Colors.grey.shade300,
      };

  Color _iconColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => Colors.green.shade700,
        VitalStatus.warning => Colors.orange.shade700,
        VitalStatus.critical => Colors.red.shade700,
        VitalStatus.unknown => Colors.grey.shade700,
      };

  @override
  Widget build(BuildContext context) {
    final sysStatus = vitals.getBloodPressureSysStatus();
    final diaStatus = vitals.getBloodPressureDiaStatus();
    final overallStatus =
        sysStatus.index > diaStatus.index ? sysStatus : diaStatus;

    final iconColor = _iconColor(overallStatus);
    final sysStr = vitals.bloodPressureSys?.toStringAsFixed(0) ?? '--';
    final diaStr = vitals.bloodPressureDia?.toStringAsFixed(0) ?? '--';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _bgColor(overallStatus),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor(overallStatus), width: 2),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Icon(
                Icons.monitor_heart,
                key: ValueKey(overallStatus),
                size: 40,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Huyết áp',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedVitalValue(
                          value: sysStr,
                          color: iconColor,
                          fontSize: 32,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            ' / ',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        AnimatedVitalValue(
                          value: diaStr,
                          color: iconColor,
                          fontSize: 32,
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'mmHg',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tâm thu / Tâm trương',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
