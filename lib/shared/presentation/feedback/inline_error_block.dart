import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class InlineErrorBlock extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const InlineErrorBlock({
    super.key,
    required this.message,
    this.retryLabel = 'Thử lại',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppStateColors.criticalBg,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.emergency.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.emergency,
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppColors.emergency,
              ),
              label: Text(
                retryLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.emergency,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.pillRadius,
                ),
                backgroundColor: AppColors.emergency.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
