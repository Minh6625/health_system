import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
import '../models/vital_signs.dart';

/// A badge that shows when data was last updated.
/// Smoothly transitions color + text between "Fresh" and "Stale" states
/// using [AnimatedSwitcher] and [AnimatedContainer] whenever [vitals] changes.
class TimestampBadge extends StatelessWidget {
  final VitalSigns vitals;

  const TimestampBadge({super.key, required this.vitals});

  String _getFullLabel(bool isStale) {
    final timeStr = _formatTime(vitals.timestamp);
    if (isStale) return 'Mất kết nối từ $timeStr';

    final timeDiff = DateTime.now().difference(vitals.timestamp);
    if (timeDiff.inSeconds < 60) return 'Vừa cập nhật lúc $timeStr';
    if (timeDiff.inMinutes < 60) {
      return 'Cập nhật ${timeDiff.inMinutes} phút trước ($timeStr)';
    }
    return 'Cập nhật lúc $timeStr';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isStale = vitals.isStale;
    final bgColor = isStale ? AppStateColors.warningBg : AppStateColors.infoBg;
    final borderColor = isStale ? AppColors.warning : AppColors.info;
    final iconColor = isStale ? AppColors.warning : AppColors.info;
    final textColor = isStale ? AppColors.warning : AppColors.info;
    final icon = isStale ? Icons.warning_amber : Icons.check_circle;
    final label = _getFullLabel(isStale);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionGapSm.toDouble() + 2,
        vertical: AppSpacing.sectionGapSm.toDouble() - 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              icon,
              key: ValueKey(isStale),
              color: iconColor,
              size: 20,
            ),
          ),
          SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                label,
                key: ValueKey(label),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  color: textColor,
                ),
              ),
            ),
          ),
          if (isStale)
            Icon(Icons.sync_problem, color: AppColors.warning, size: 20),
        ],
      ),
    );
  }
}
