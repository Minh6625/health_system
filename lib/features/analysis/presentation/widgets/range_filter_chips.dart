import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class RangeFilterChips extends StatelessWidget {
  final String currentRange;
  final Function(String) onRangeSelected;

  const RangeFilterChips({
    super.key,
    required this.currentRange,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('7d', '7 ngày'),
          const SizedBox(width: AppSpacing.gapMd),
          _buildChip('30d', '30 ngày'),
          const SizedBox(width: AppSpacing.gapMd),
          _buildChip('90d', '90 ngày'),
        ],
      ),
    );
  }

  Widget _buildChip(String value, String label) {
    final isSelected = currentRange == value;
    return InkWell(
      onTap: () => onRangeSelected(value),
      borderRadius: AppRadii.pillRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gapLg,
          vertical: AppSpacing.gapSm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: AppRadii.pillRadius,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.strokeSoft,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.bgSurface : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
