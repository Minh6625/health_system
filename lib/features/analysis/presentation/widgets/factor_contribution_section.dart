import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_detail_entity.dart';

class FactorContributionSection extends StatefulWidget {
  final List<FactorBreakdown> breakdown;
  final Function(String routeTarget)? onFactorTap;

  /// Number of factor cards rendered before the "Xem thêm" toggle. The
  /// remaining items stay collapsed until the user expands the section.
  static const int collapsedCount = 3;

  const FactorContributionSection({
    super.key,
    required this.breakdown,
    this.onFactorTap,
  });

  @override
  State<FactorContributionSection> createState() =>
      _FactorContributionSectionState();
}

class _FactorContributionSectionState extends State<FactorContributionSection> {
  bool _isExpanded = false;

  /// Sorts the breakdown by descending contribution so the "top 3" we show
  /// by default are actually the most impactful factors. The UI relies on
  /// this ordering for the visual contribution bars.
  List<FactorBreakdown> get _sorted {
    final sorted = List<FactorBreakdown>.from(widget.breakdown);
    sorted.sort(
      (a, b) => b.contributionScore.compareTo(a.contributionScore),
    );
    return sorted;
  }

  double _maxContribution(List<FactorBreakdown> items) {
    double maxValue = 0;
    for (final item in items) {
      if (item.contributionScore > maxValue) {
        maxValue = item.contributionScore;
      }
    }
    return maxValue;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.breakdown.isEmpty) return const SizedBox.shrink();

    final sorted = _sorted;
    final maxContribution = _maxContribution(sorted);
    final total = sorted.length;
    final collapsed = total > FactorContributionSection.collapsedCount;
    final visible = (collapsed && !_isExpanded)
        ? sorted.take(FactorContributionSection.collapsedCount).toList()
        : sorted;
    final hiddenCount = total - FactorContributionSection.collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mức độ đóng góp của các yếu tố',
                style: AppTextStyles.sectionTitle,
              ),
            ),
            if (collapsed)
              Text(
                _isExpanded ? '$total / $total' : '${visible.length} / $total',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapMd),
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.gapMd),
            child: _FactorContributionCard(
              item: item,
              maxContribution: maxContribution,
              onTap: () => widget.onFactorTap?.call(item.routeTarget),
            ),
          ),
        if (collapsed)
          _ExpandToggle(
            isExpanded: _isExpanded,
            hiddenCount: hiddenCount,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),
      ],
    );
  }
}

/// Bottom toggle row used to expand / collapse the secondary factors.
/// Renders a tonal pill with `Xem thêm (N) yếu tố` / `Thu gọn`.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.isExpanded,
    required this.hiddenCount,
    required this.onTap,
  });

  final bool isExpanded;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gapMd,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary.withValues(alpha: 0.06),
          borderRadius: AppRadii.cardRadius,
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              isExpanded ? 'Thu gọn' : 'Xem thêm $hiddenCount yếu tố',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
