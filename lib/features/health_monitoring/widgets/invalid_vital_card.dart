import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';

class InvalidVitalCard extends StatelessWidget {
  const InvalidVitalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.sectionGapXl.toDouble() + 8,
        horizontal: AppSpacing.gapLg,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.gapLg,
              vertical: AppSpacing.gapSm,
            ),
            decoration: BoxDecoration(
              color: AppStateColors.warningBg,
              borderRadius: AppRadii.pillRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
                SizedBox(width: AppSpacing.gapSm),
                Text(
                  'Không đo được',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapXl.toDouble()),
          Text(
            '--',
            style: AppTextStyles.displayCompact.copyWith(
              fontSize: 84,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
