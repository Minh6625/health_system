import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class FamilyAttentionSummaryBanner extends StatelessWidget {
  final int count;

  const FamilyAttentionSummaryBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.gapSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.sectionGapSm,
      ),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 24),
          const SizedBox(width: AppSpacing.sectionGapSm),
          Expanded(
            child: Text(
              'Có $count người đang cần cần bạn chú ý theo dõi.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
