import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';

class VitalDetailSkeleton extends StatelessWidget {
  const VitalDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenHorizontalPadding.copyWith(
        top: AppSpacing.sectionGapXl.toDouble(),
        bottom: AppSpacing.sectionGapXl.toDouble(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Loading Value Card
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
            ),
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.sectionGapXl.toDouble() + 8,
              horizontal: AppSpacing.gapLg,
            ),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.strokeSoft,
                    borderRadius: AppRadii.pillRadius,
                  ),
                ),
                SizedBox(height: AppSpacing.sectionGapXl.toDouble()),
                Container(
                  width: 160,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.strokeSoft,
                    borderRadius: AppRadii.cardRadius,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapXl.toDouble()),

          // Loading Chart section
          Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(AppRadii.radiusSm),
            ),
          ),
          SizedBox(height: AppSpacing.gapMd),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(AppRadii.radiusXl),
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapXl.toDouble()),

          // Loading Education Text
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: AppRadii.cardRadius,
            ),
          ),
        ],
      ),
    );
  }
}
