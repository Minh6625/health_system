import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_history_entity.dart';
import '../../domain/entities/risk_report_entity.dart';
import 'risk_level_pill.dart';

class RiskHistoryItemCard extends StatelessWidget {
  final RiskHistoryItemEntity item;
  final VoidCallback onTap;

  const RiskHistoryItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    switch (item.level) {
      case RiskLevel.low:
        scoreColor = AppColors.success;
        break;
      case RiskLevel.medium:
        scoreColor = AppColors.warning;
        break;
      case RiskLevel.critical:
        scoreColor = AppColors.critical;
        break;
    }

    final String timeStr = DateFormat('HH:mm').format(item.analyzedAt);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Container(
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
                Row(
                  children: [
                    Text(
                      item.healthScore.round().toString(),
                      style: AppTextStyles.displayCompact.copyWith(
                        color: scoreColor,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gapSm),
                    RiskLevelPill(level: item.level),
                  ],
                ),
                Text(timeStr, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: AppSpacing.gapMd),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.reasonPreview.isNotEmpty
                            ? item.reasonPreview
                            : 'Không có tóm tắt',
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.isStale) ...[
                        const SizedBox(height: AppSpacing.gapXs),
                        Text(
                          'Dữ liệu cũ',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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
          ],
        ),
      ),
    );
  }
}
