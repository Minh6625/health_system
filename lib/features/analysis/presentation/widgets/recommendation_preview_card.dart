import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class RecommendationPreviewCard extends StatelessWidget {
  final List<String> recommendations;

  const RecommendationPreviewCard({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapLg),
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
              const Text(
                'Khuyến nghị',
                style: AppTextStyles.sectionTitle,
              ),
              Text(
                'Xem đầy đủ',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          ...recommendations.take(2).map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.gapMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.gapMd),
                    Expanded(
                      child: Text(
                        rec,
                        style: AppTextStyles.body,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
