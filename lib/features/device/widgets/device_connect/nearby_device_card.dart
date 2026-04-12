import 'package:flutter/material.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class NearbyDeviceCard extends StatelessWidget {
  final MockBleDevice device;
  final VoidCallback onTap;

  const NearbyDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData = Icons.watch;
    if (device.deviceType == 'fitness_band') {
      iconData = Icons.watch_later_outlined;
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: AppSpacing.gapMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        side: BorderSide(color: AppColors.strokeSoft),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sectionGapMd),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.gapMd),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                ),
                child: Icon(iconData, color: AppColors.brandPrimary, size: 32),
              ),
              SizedBox(width: AppSpacing.sectionGapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: AppTextStyles.bodyMedium,
                    ),
                    SizedBox(height: AppSpacing.gapXs),
                    Text(
                      'Loại: ${device.deviceType == 'smartwatch' ? 'Đồng hồ thông minh' : 'Vòng đeo tay'}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
