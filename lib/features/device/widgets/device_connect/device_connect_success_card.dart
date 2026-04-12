import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DeviceConnectSuccessCard extends StatelessWidget {
  const DeviceConnectSuccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sectionGapXl + 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sectionGapXl + 8),
            decoration: BoxDecoration(
              color: AppStateColors.successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, size: 80, color: AppColors.success),
          ),
          SizedBox(height: AppSpacing.sectionGapXl + 8),
          Text(
            'Kết nối thành công!',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sectionGapMd),
          Text(
            'Đồng hồ của bạn đã được thêm vào hệ thống và sẵn sàng theo dõi.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          const CircularProgressIndicator.adaptive(),
        ],
      ),
    );
  }
}
