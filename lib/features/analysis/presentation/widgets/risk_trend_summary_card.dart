import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_history_entity.dart';
import 'health_score_delta_badge.dart';
import 'health_score_trend_chart.dart';

class RiskTrendSummaryCard extends StatelessWidget {
  final RiskHistorySummary summary;

  const RiskTrendSummaryCard({super.key, required this.summary});

  String _formatScore(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildStatsHeader(bool compact) {
    final averageBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Điểm sức khoẻ trung bình', style: AppTextStyles.caption),
        Text(
          _formatScore(summary.healthAverage),
          style: AppTextStyles.displayCompact.copyWith(fontSize: 32),
        ),
      ],
    );

    final highLowBlock = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          'Cao nhất: ${_formatScore(summary.healthHighest)}',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.gapXs),
        Text(
          'Thấp nhất: ${_formatScore(summary.healthLowest)}',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          averageBlock,
          const SizedBox(height: AppSpacing.gapMd),
          highLowBlock,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: averageBlock),
        const SizedBox(width: AppSpacing.gapMd),
        Flexible(child: highLowBlock),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
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
              _buildStatsHeader(compact),
              const SizedBox(height: AppSpacing.gapMd),
              if (summary.healthDeltaVsPreviousPeriod.abs() > 0.0001 ||
                  summary.healthTrendPoints.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: HealthScoreDeltaBadge(
                    delta: summary.healthDeltaVsPreviousPeriod,
                    comparedTo: 'kỳ trước',
                  ),
                ),
              if (summary.healthTrendPoints.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.gapLg),
                HealthScoreTrendChart(
                  data: summary.healthTrendPoints,
                ),
                const SizedBox(height: AppSpacing.gapSm),
                Text(
                  'Ngưỡng: ≥80 ổn định · 60–80 cần theo dõi · <60 nguy hiểm',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

