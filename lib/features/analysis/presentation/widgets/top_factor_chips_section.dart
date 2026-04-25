import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_entity.dart';

class TopFactorChipsSection extends StatelessWidget {
  final List<TopFactor> factors;

  const TopFactorChipsSection({super.key, required this.factors});

  double _maxImpact() {
    double maxValue = 0;
    for (final f in factors) {
      if (f.impact > maxValue) maxValue = f.impact;
    }
    return maxValue;
  }

  @override
  Widget build(BuildContext context) {
    if (factors.isEmpty) return const SizedBox.shrink();

    final richFactors = factors.where((f) => f.hasShapContext).toList();
    final useRichLayout = richFactors.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Yếu tố chính', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.gapMd),
        if (useRichLayout)
          _RichFactorList(factors: factors, maxImpact: _maxImpact())
        else
          _LegacyFactorChips(factors: factors),
      ],
    );
  }
}

class _LegacyFactorChips extends StatelessWidget {
  final List<TopFactor> factors;

  const _LegacyFactorChips({required this.factors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.gapSm,
      runSpacing: AppSpacing.gapSm,
      children: factors.map((f) {
        return Chip(
          label: Text(
            f.label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.bgSurface,
          side: const BorderSide(color: AppColors.strokeSoft),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.radiusSm),
          ),
        );
      }).toList(),
    );
  }
}

class _RichFactorList extends StatelessWidget {
  final List<TopFactor> factors;
  final double maxImpact;

  const _RichFactorList({required this.factors, required this.maxImpact});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < factors.length; i++) ...[
          _RichFactorTile(
            factor: factors[i],
            maxImpact: maxImpact,
          ),
          if (i != factors.length - 1)
            const SizedBox(height: AppSpacing.gapSm),
        ],
      ],
    );
  }
}

class _RichFactorTile extends StatelessWidget {
  final TopFactor factor;
  final double maxImpact;

  const _RichFactorTile({required this.factor, required this.maxImpact});

  Color _resolveColor() {
    if (factor.isRiskUp) return AppColors.critical;
    if (factor.isRiskDown) return AppColors.success;
    return AppColors.brandPrimary;
  }

  IconData _directionIcon() {
    if (factor.isRiskUp) return Icons.arrow_upward_rounded;
    if (factor.isRiskDown) return Icons.arrow_downward_rounded;
    return Icons.info_outline;
  }

  double _fillFraction() {
    if (maxImpact <= 0) return 0.0;
    final ratio = factor.impact / maxImpact;
    return ratio.clamp(0.08, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final showReason = factor.reason.trim().isNotEmpty;
    final showValue = factor.featureValue.trim().isNotEmpty &&
        factor.featureValue.trim() != '--';

    return Container(
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
            children: [
              Icon(_directionIcon(), color: color, size: 18),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Text(
                  factor.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showValue)
                Text(
                  factor.featureValue,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (showReason) ...[
            const SizedBox(height: AppSpacing.gapXs),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                factor.reason,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (factor.impact > 0) ...[
            const SizedBox(height: AppSpacing.gapSm),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _fillFraction(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
