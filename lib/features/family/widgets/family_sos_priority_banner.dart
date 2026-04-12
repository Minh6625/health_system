import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class FamilySOSPriorityBanner extends StatelessWidget {
  final int sosCount;
  final VoidCallback onTap;

  const FamilySOSPriorityBanner({
    super.key,
    required this.sosCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sosCount == 0) return const SizedBox.shrink();

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
        color: AppColors.critical,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.critical.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.bgSurface,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.sectionGapSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Có $sosCount người đang cần trợ giúp ngay!',
                  style: const TextStyle(
                    color: AppColors.bgSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.gapSm),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              foregroundColor: AppColors.critical,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sectionGapSm,
                vertical: 0,
              ),
              minimumSize: const Size(60, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusSm),
              ),
            ),
            child: const Text('Xem ngay'),
          ),
        ],
      ),
    );
  }
}
