import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_detail_entity.dart';
import '../../domain/entities/risk_report_entity.dart';
import 'risk_level_pill.dart';

class RiskDetailSummaryCard extends StatelessWidget {
  final RiskReportDetailEntity detail;

  const RiskDetailSummaryCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    switch (detail.level) {
      case RiskLevel.low:
        scoreColor = AppColors.success;
        break;
      case RiskLevel.moderate:
        scoreColor = AppColors.warning;
        break;
      case RiskLevel.high:
      case RiskLevel.critical:
        scoreColor = AppColors.critical;
        break;
    }

    final String timeStr = DateFormat('HH:mm, dd/MM').format(detail.analyzedAt);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoàn thành lúc $timeStr',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 8),
                    RiskLevelPill(level: detail.level),
                  ],
                ),
              ),
              Text(
                detail.score.toString(),
                style: AppTextStyles.displayCompact.copyWith(
                  color: scoreColor,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Divider(color: AppColors.strokeSoft.withValues(alpha: 0.5)),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            detail.summary,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
