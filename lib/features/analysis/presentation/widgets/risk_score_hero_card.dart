import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_entity.dart';
import 'risk_level_pill.dart';
import 'package:intl/intl.dart';

class RiskScoreHeroCard extends StatelessWidget {
  final RiskReportEntity report;

  const RiskScoreHeroCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    switch (report.level) {
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

    final int delta = report.score - report.previousScore;
    final String deltaStr = delta >= 0 ? '+$delta' : '$delta';
    final String timeStr = DateFormat('HH:mm, dd/MM').format(report.analyzedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
        boxShadow: AppShadows.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Điểm đánh giá hiện tại', style: AppTextStyles.bodyMedium),
              Text(timeStr, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Score Capsule
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scoreColor.withValues(alpha: 0.3),
                    width: 4,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  report.score.toString(),
                  style: AppTextStyles.displayCompact.copyWith(
                    color: scoreColor,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.gapLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RiskLevelPill(level: report.level),
                    const SizedBox(height: AppSpacing.gapSm),
                    Text(
                      report.displayStatus,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gapXs),
                    Text(
                      '$deltaStr so với lần trước',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
