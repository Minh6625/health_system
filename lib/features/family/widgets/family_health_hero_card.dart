import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class FamilyHealthHeroCard extends StatelessWidget {
  final int totalCount;
  final int stableCount;
  final int attentionCount;

  const FamilyHealthHeroCard({
    super.key,
    required this.totalCount,
    required this.stableCount,
    required this.attentionCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.gapLg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.sectionGapSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryLight,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng tiêu đề gộp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.family_restroom,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gia đình của bạn · $totalCount người đang theo dõi',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stat chips
          Row(
            children: [
              _buildStatChip(
                label: 'Tổng',
                value: totalCount.toString(),
                color: AppColors.brandPrimary,
                bgColor: AppColors.bgSurface,
              ),
              const SizedBox(width: 6),
              _buildStatChip(
                label: 'Ổn định',
                value: stableCount.toString(),
                color: AppColors.success,
                bgColor: AppStateColors.successBg,
              ),
              const SizedBox(width: 6),
              _buildStatChip(
                label: 'Cần chú ý',
                value: attentionCount.toString(),
                color: AppColors.warning,
                bgColor: AppStateColors.warningBg,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gapSm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.gapXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
