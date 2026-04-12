import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class AttentionZoneCard extends StatelessWidget {
  const AttentionZoneCard({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<DeviceProvider>().needsAttentionDevices.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.gapMd),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
          ),
          SizedBox(width: AppSpacing.sectionGapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cần kiểm tra ngay',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Có $count thiết bị đang pin yếu hoặc mất kết nối lâu.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning,
                    height: 1.4,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: AppSpacing.gapMd),
                InkWell(
                  onTap: () {},
                  child: Text(
                    'Xem thiết bị cần chú ý →',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
