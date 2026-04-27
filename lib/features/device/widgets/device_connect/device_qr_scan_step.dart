import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import 'device_connect_demo_banner.dart';

class DeviceQrScanStep extends StatelessWidget {
  const DeviceQrScanStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sectionGapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DeviceConnectDemoBanner(),
          SizedBox(height: AppSpacing.sectionGapMd),
          Text(
            'Quét mã QR',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            'Hướng camera vào mã QR trên màn hình đồng hồ đang bật.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
                border: Border.all(color: AppColors.brandPrimary, width: 3),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 80, color: Colors.black26),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 120),
                      CircularProgressIndicator(color: AppColors.brandPrimary),
                      SizedBox(height: AppSpacing.sectionGapMd),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sectionGapMd,
                          vertical: AppSpacing.gapSm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(AppRadii.radiusXl),
                        ),
                        child: Text(
                          'Đang tìm mã...',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
