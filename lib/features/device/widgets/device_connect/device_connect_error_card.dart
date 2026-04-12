import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../providers/device_connect_provider.dart';

class DeviceConnectErrorCard extends StatelessWidget {
  const DeviceConnectErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionGapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sectionGapXl),
            decoration: BoxDecoration(
              color: AppStateColors.criticalBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded, size: 64, color: AppColors.critical),
          ),
          SizedBox(height: AppSpacing.sectionGapXl),
          Text(
            'Không thể kết nối',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.gapMd),
          Text(
            provider.errorMessage ?? 'Đã có lỗi xảy ra trong quá trình nhận diện. Vui lòng thử lại.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: provider.backToIntro,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.radiusLg)),
              elevation: 0,
            ),
            child: const Text('Thử lại', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
