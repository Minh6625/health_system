import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class RecommendationPreviewCard extends StatelessWidget {
  final List<String> recommendations;

  /// F-10 (M-2): callback the host screen wires to a "show all
  /// recommendations" navigation. When `null`, the "Xem đầy đủ" CTA is
  /// hidden entirely instead of rendering a clickable-looking label that
  /// silently does nothing (the original bug). Hosts that have a real
  /// destination pass a non-null callback; hosts that don't, omit the
  /// argument and the user never sees a dead link.
  final VoidCallback? onSeeAll;

  const RecommendationPreviewCard({
    super.key,
    required this.recommendations,
    this.onSeeAll,
  });

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
              const Text('Khuyến nghị', style: AppTextStyles.sectionTitle),
              if (onSeeAll != null)
                InkWell(
                  key: const ValueKey('recommendation-preview-see-all'),
                  onTap: onSeeAll,
                  borderRadius: AppRadii.pillRadius,
                  child: Padding(
                    // Pad so the tap target meets the 48dp accessibility
                    // floor even when the visual chrome stays minimal.
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gapSm,
                      vertical: AppSpacing.gapXs,
                    ),
                    child: Text(
                      'Xem đầy đủ',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          ...recommendations
              .take(2)
              .map(
                (rec) => Padding(
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
                      Expanded(child: Text(rec, style: AppTextStyles.body)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
