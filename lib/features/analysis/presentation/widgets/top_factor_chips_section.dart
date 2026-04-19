import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_entity.dart';

class TopFactorChipsSection extends StatelessWidget {
  final List<TopFactor> factors;

  const TopFactorChipsSection({super.key, required this.factors});

  @override
  Widget build(BuildContext context) {
    if (factors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Yếu tố chính', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.gapMd),
        Wrap(
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
        ),
      ],
    );
  }
}
