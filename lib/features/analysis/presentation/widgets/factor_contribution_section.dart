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

  double _maxContribution() {
    double maxValue = 0;
    for (final item in breakdown) {
      if (item.contributionScore > maxValue) {
        maxValue = item.contributionScore;
      }
    }
    return maxValue;
  }

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();
    final maxContribution = _maxContribution();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mức độ đóng góp của các yếu tố',
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.gapMd),
        ...breakdown.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.gapMd),
            child: _FactorContributionCard(
              item: item,
              maxContribution: maxContribution,
              onTap: () => onFactorTap?.call(item.routeTarget),
            ),
          ),
        ),
      ],
    );
  }
}

class _FactorContributionCard extends StatelessWidget {
  final FactorBreakdown item;
  final double maxContribution;
  final VoidCallback onTap;

  const _FactorContributionCard({
    required this.item,
    required this.maxContribution,
    required this.onTap,
  });

  String _formatContribution(double value) {
    final hasShap = item.hasShapContext;
    final prefix = item.isRiskDown ? '-' : '+';
    if (hasShap) {
      return '$prefix${value.toStringAsFixed(2)}';
    }
    if (value == value.roundToDouble()) {
      return '+${value.toInt()}';
    }
    return '+${value.toStringAsFixed(2)}';
  }

  Color _resolveColor() {
    if (item.isRiskUp) return AppColors.critical;
    if (item.isRiskDown) return AppColors.success;
    switch (item.impactLevel) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'high':
      default:
        return AppColors.critical;
    }
  }

  double _resolveFillFraction() {
    // When SHAP impact is available, scale relative to the largest
    // contribution in the current breakdown for a meaningful visual.
    if (item.hasShapContext && maxContribution > 0) {
      final ratio = item.contributionScore / maxContribution;
      return ratio.clamp(0.08, 1.0);
    }
    // Legacy fallback: use impactLevel buckets.
    switch (item.impactLevel) {
      case 'low':
        return 0.2;
      case 'medium':
        return 0.5;
      case 'high':
      default:
        return 0.9;
    }
  }

  IconData? _directionIcon() {
    if (item.isRiskUp) return Icons.arrow_upward_rounded;
    if (item.isRiskDown) return Icons.arrow_downward_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final impactColor = _resolveColor();
    final fillFraction = _resolveFillFraction();
    final directionIcon = _directionIcon();
    final showReason = item.reason.trim().isNotEmpty;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (directionIcon != null) ...[
                  Icon(directionIcon, color: impactColor, size: 18),
                  const SizedBox(width: AppSpacing.gapXs),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.value} ${item.unit}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.gapSm),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            if (showReason) ...[
              const SizedBox(height: AppSpacing.gapXs),
              Text(
                item.reason,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.gapMd),
            Row(
              children: [
                Text(
                  _formatContribution(item.contributionScore),
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
                      borderRadius: BorderRadius.circular(
                        AppRadii.radiusSm / 2,
                      ),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fillFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: impactColor,
                          borderRadius: BorderRadius.circular(
                            AppRadii.radiusSm / 2,
                          ),
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
