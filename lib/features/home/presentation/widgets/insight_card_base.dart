import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class InsightCardBase extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final String? trailingCtaLabel;
  final VoidCallback? onTap;
  final Widget child;

  const InsightCardBase({
    super.key,
    required this.leadingIcon,
    required this.title,
    this.trailingCtaLabel,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: AppSpacing.cardPadding,
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
                  Icon(leadingIcon, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapMd),
              child,
              if (trailingCtaLabel != null && onTap != null) ...[
                const SizedBox(height: AppSpacing.gapSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      trailingCtaLabel!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
