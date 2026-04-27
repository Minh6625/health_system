import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

/// XAI explanation block: "Chi tiết phát hiện té ngã" card.
///
/// Renders the detector confidence (multiplied by 100 for display because
/// the backend stores it in the canonical 0.0-1.0 range used by
/// `fall_event.confidence` and `risk_score`), the optional human-readable
/// `triggerReason`, and the chronological list of timeline events emitted
/// by the fall-detection pipeline.
class EmergencySOSTimelineBlock extends StatelessWidget {
  final FallDetectionXAIModel xai;

  const EmergencySOSTimelineBlock({super.key, required this.xai});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.warning, width: 2),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, size: 20, color: AppColors.warning),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Chi tiết phát hiện té ngã',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            // Backend stores confidence as 0.0-1.0; multiply for human display.
            'Độ tin cậy: ${(xai.confidence * 100).toStringAsFixed(0)}%',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (xai.triggerReason != null &&
              xai.triggerReason!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gapXs),
            Text(
              xai.triggerReason!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Timeline:',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapSm),
          ...xai.timeline.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${event.time} - ${event.description}',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
