import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_detail_entity.dart';

class SupportingMetricsSnapshotCard extends StatelessWidget {
  final SnapshotMetrics snapshot;

  const SupportingMetricsSnapshotCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chỉ số tại thời điểm đánh giá',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Wrap(
            spacing: AppSpacing.gapLg,
            runSpacing: AppSpacing.gapMd,
            children: [
              _buildMetric('Nhịp tim', '${snapshot.heartRate} bpm'),
              _buildMetric('SpO2', '${snapshot.spO2}%'),
              _buildMetric('Huyết áp', '${snapshot.sysBp}/${snapshot.diaBp} mmHg'),
              _buildMetric('Nhiệt độ', '${snapshot.bodyTemp}°C'),
              _buildMetric('HRV', '${snapshot.hrv} ms'),
              _buildMetric('MAP', '${snapshot.mapVal}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.gapXs),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
