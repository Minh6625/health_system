import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import 'health_score_delta_badge.dart';
import 'health_score_trend_chart.dart';

/// 7-day health-score trend card shown on the latest-report screen.
///
/// Renders a [HealthScoreTrendChart] with axis labels + threshold lines and
/// optionally a [HealthScoreDeltaBadge] comparing the most recent point to
/// the previous report, sourced from `report.healthDelta`.
class RiskTrendPreviewCard extends StatelessWidget {
  final List<int> trend7d;

  /// Health-score delta vs the previous report. Positive means health
  /// improved. Pass `null` if no prior comparison exists.
  final int? healthDelta;

  const RiskTrendPreviewCard({
    super.key,
    required this.trend7d,
    this.healthDelta,
  });

  @override
  Widget build(BuildContext context) {
    if (trend7d.isEmpty) return const SizedBox.shrink();

    final dayLabels = _buildDayLabels(trend7d.length);

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
            children: [
              const Expanded(
                child: Text(
                  'Xu hướng 7 ngày',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              if (healthDelta != null)
                HealthScoreDeltaBadge(
                  delta: healthDelta!.toDouble(),
                  comparedTo: 'lần trước',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          HealthScoreTrendChart(data: trend7d, xLabels: dayLabels),
          const SizedBox(height: AppSpacing.gapSm),
          Text(
            'Ngưỡng: ≥80 ổn định · 60–80 cần theo dõi · <60 nguy hiểm',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates short day labels for the X-axis ("T2"..."CN" style isn't
  /// available without a date input, so we fall back to "Ngày -6"..."Hôm
  /// nay" relative labels which are still informative).
  List<String> _buildDayLabels(int n) {
    if (n == 0) return const [];
    return [
      for (int i = 0; i < n; i++)
        if (i == n - 1) 'Hôm nay' else 'N${-(n - 1 - i)}',
    ];
  }
}
