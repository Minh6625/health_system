import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class RelatedDrilldownSection extends StatelessWidget {
  final VoidCallback? onVitalTap;
  final VoidCallback? onSleepTap;

  const RelatedDrilldownSection({super.key, this.onVitalTap, this.onSleepTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Truy cập nhanh', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.gapMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildDrilldownButton(
                icon: Icons.monitor_heart_outlined,
                label: 'Chi tiết\nChỉ số HT',
                onTap: onVitalTap,
              ),
            ),
            const SizedBox(width: AppSpacing.gapLg),
            Expanded(
              child: _buildDrilldownButton(
                icon: Icons.bedtime_outlined,
                label: 'Báo cáo\nGiấc ngủ',
                onTap: onSleepTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDrilldownButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapLg),
        side: const BorderSide(color: AppColors.strokeSoft),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        foregroundColor: AppColors.textPrimary,
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.brandPrimary),
          const SizedBox(height: AppSpacing.gapSm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
