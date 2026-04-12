import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DeviceHealthHeroCard extends StatelessWidget {
  const DeviceHealthHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final total = provider.devices.length;
    final attention = provider.needsAttentionDevices.length;
    final healthy = total - attention;

    return Container(
      padding: EdgeInsets.all(AppSpacing.sectionGapLg),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thiết bị của bạn',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'Hãy kết nối thiết bị để theo dõi'
                : (healthy == total
                    ? 'Tất cả thiết bị đang hoạt động tốt'
                    : '$healthy thiết bị đang hoạt động tốt'),
            style: AppTextStyles.body.copyWith(
              color: AppColors.bgElevated,
              height: 1.4,
            ),
          ),
          SizedBox(height: AppSpacing.sectionGapXl),
          Row(
            children: [
              Expanded(child: _buildMetricTile('Tổng', total.toString())),
              SizedBox(width: AppSpacing.gapMd),
              Expanded(child: _buildMetricTile('Ổn định', healthy.toString())),
              SizedBox(width: AppSpacing.gapMd),
              Expanded(child: _buildMetricTile('Cần chú ý', attention.toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.vitalValue.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          SizedBox(height: AppSpacing.gapXs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.bgElevated,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
