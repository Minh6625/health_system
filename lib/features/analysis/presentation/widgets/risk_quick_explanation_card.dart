import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_entity.dart';

class RiskQuickExplanationCard extends StatelessWidget {
  final String summary;
  final List<TopFactor> topFactors;

  const RiskQuickExplanationCard({
    super.key,
    required this.summary,
    this.topFactors = const [],
  });

  String _buildResolvedSummary() {
    // Build a SHAP-informed summary when reasons are available,
    // falling back to the static per-level summary otherwise.
    final rich = topFactors
        .where((f) => f.reason.trim().isNotEmpty)
        .take(2)
        .map((f) => f.reason.trim())
        .toList();
    if (rich.isEmpty) return summary;
    final joined = rich.join('; ');
    return '$joined.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapMd),
      decoration: BoxDecoration(
        color: AppStateColors.infoBg,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Text(
              _buildResolvedSummary(),
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
