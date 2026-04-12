import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_detail_entity.dart';

class FactorContributionSection extends StatelessWidget {
  final List<FactorBreakdown> breakdown;
  final Function(String routeTarget)? onFactorTap;

  const FactorContributionSection({
    super.key,
    required this.breakdown,
    this.onFactorTap,
  });

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mức độ đóng góp của các yếu tố',
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.gapMd),
        ...breakdown.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapMd),
              child: _FactorContributionCard(
                item: item,
                onTap: () => onFactorTap?.call(item.routeTarget),
              ),
            )),
      ],
    );
  }
}

class _FactorContributionCard extends StatelessWidget {
  final FactorBreakdown item;
  final VoidCallback onTap;

  const _FactorContributionCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color impactColor;
    double fillFraction;

    switch (item.impactLevel) {
      case 'low':
        impactColor = AppColors.success;
        fillFraction = 0.2;
        break;
      case 'medium':
        impactColor = AppColors.warning;
        fillFraction = 0.5;
        break;
      case 'high':
      default:
        impactColor = AppColors.critical;
        fillFraction = 0.9;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gapMd),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: AppColors.strokeSoft),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.value} ${item.unit}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.gapSm),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: AppSpacing.gapMd),
            Row(
              children: [
                Text(
                  '+${item.contributionScore}',
                  style: AppTextStyles.caption.copyWith(
                    color: impactColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.gapSm),
                Expanded(
                  child: Container(
                    height: AppSpacing.gapSm,
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(AppRadii.radiusSm / 2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fillFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: impactColor,
                          borderRadius: BorderRadius.circular(AppRadii.radiusSm / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
