import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

enum VitalMetricVisualState { normal, warning, critical, stale, empty }

enum VitalMetricType { heartRate, spo2, bloodPressure, temperature }

class VitalMetricItem {
  final VitalMetricType type;
  final String label;
  final String value;
  final String statusLabel;
  final VitalMetricVisualState visualState;
  final VoidCallback onTap;

  const VitalMetricItem({
    required this.type,
    required this.label,
    required this.value,
    required this.statusLabel,
    this.visualState = VitalMetricVisualState.normal,
    required this.onTap,
  });
}

class VitalMetricCard extends StatelessWidget {
  final VitalMetricItem item;

  const VitalMetricCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color accentColor;
    Color bgColor = AppColors.bgSurface;
    IconData iconData;

    switch (item.type) {
      case VitalMetricType.heartRate:
        iconData = Icons.favorite_rounded;
        break;
      case VitalMetricType.spo2:
        iconData =
            Icons.water_drop_rounded; // Assuming standard flutter icons for now
        break;
      case VitalMetricType.bloodPressure:
        iconData = Icons.monitor_heart_rounded;
        break;
      case VitalMetricType.temperature:
        iconData = Icons.thermostat_rounded;
        break;
    }

    switch (item.visualState) {
      case VitalMetricVisualState.normal:
        borderColor = AppColors.strokeSoft;
        accentColor = AppColors.success;
        bgColor = AppStateColors.successBg;
        break;
      case VitalMetricVisualState.warning:
        borderColor = AppColors.warning;
        accentColor = AppColors.warning;
        bgColor = AppStateColors.warningBg;
        break;
      case VitalMetricVisualState.critical:
        borderColor = AppColors.emergency;
        accentColor = AppColors.emergency;
        bgColor = AppStateColors.criticalBg;
        break;
      case VitalMetricVisualState.stale:
        borderColor = AppColors.strokeSoft;
        accentColor = AppColors.textSecondary;
        bgColor = AppStateColors.infoBg;
        break;
      case VitalMetricVisualState.empty:
        borderColor = AppColors.strokeSoft;
        accentColor = AppColors.textSecondary;
        bgColor = AppColors.bgElevated;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: borderColor,
              width: item.visualState == VitalMetricVisualState.warning
                  ? 1.5
                  : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: item.visualState == VitalMetricVisualState.warning ||
                              item.visualState == VitalMetricVisualState.critical
                          ? accentColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: accentColor, size: 28),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.value, 
                style: AppTextStyles.vitalValue.copyWith(
                  fontSize: 28, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                )
              ),
              const SizedBox(height: AppSpacing.gapSm),
              Row(
                children: [
                  if (item.visualState == VitalMetricVisualState.warning)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.warning_amber_rounded, size: 14, color: accentColor),
                    ),
                  Text(
                    item.statusLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: item.visualState == VitalMetricVisualState.stale
                          ? null
                          : accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
