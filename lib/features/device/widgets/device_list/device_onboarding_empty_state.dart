import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DeviceOnboardingEmptyState extends StatelessWidget {
  const DeviceOnboardingEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionGapXl,
        vertical: 48,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.watch_rounded, size: 64, color: AppColors.brandPrimary),
          ),
          SizedBox(height: AppSpacing.sectionGapXl),
          Text(
            'Bắt đầu theo dõi sức khoẻ',
            style: AppTextStyles.sectionTitle,
          ),
          SizedBox(height: AppSpacing.gapMd),
          Text(
            'Kết nối đồng hồ thông minh hoặc thiết bị y tế\nđể xem các chỉ số liên tục và thông minh.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
