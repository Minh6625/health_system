import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
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
        VitalStatus.normal => AppStateColors.successBg,
        VitalStatus.warning => AppStateColors.warningBg,
        VitalStatus.critical => AppStateColors.criticalBg,
        VitalStatus.unknown => AppColors.bgPrimary,
      };

  Color _borderColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => AppColors.success,
        VitalStatus.warning => AppColors.warning,
        VitalStatus.critical => AppColors.critical,
        VitalStatus.unknown => AppColors.strokeSoft,
      };

  Color _iconColor(VitalStatus s) => switch (s) {
        VitalStatus.normal => AppColors.success,
        VitalStatus.warning => AppColors.warning,
        VitalStatus.critical => AppColors.critical,
        VitalStatus.unknown => AppColors.textSecondary,
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
      borderRadius: AppRadii.cardRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: _bgColor(overallStatus),
          borderRadius: AppRadii.cardRadius,
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
            SizedBox(width: AppSpacing.gapLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Huyết áp',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.gapXs),
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
                            style: AppTextStyles.sectionTitle.copyWith(
                              fontSize: 24,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        AnimatedVitalValue(
                          value: diaStr,
                          color: iconColor,
                          fontSize: 32,
                        ),
                        SizedBox(width: AppSpacing.gapXs),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'mmHg',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.gapXs),
                  Text(
                    'Tâm thu / Tâm trương',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
