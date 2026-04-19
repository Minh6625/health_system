import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class CompareInsightCard extends StatelessWidget {
  final double delta;

  const CompareInsightCard({super.key, required this.delta});

  @override
  Widget build(BuildContext context) {
    final bool isNotWorsening = delta <= 0;
    final Color bgColor = AppStateColors.infoBg;
    final Color iconColor = AppColors.info;
    final String text = delta < 0
        ? 'Điểm rủi ro giảm ${_format(delta.abs())} điểm so với chu kỳ trước.'
        : delta > 0
        ? 'Điểm rủi ro tăng ${_format(delta)} điểm so với chu kỳ trước.'
        : 'Điểm rủi ro giữ nguyên so với chu kỳ trước.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapMd),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNotWorsening ? Icons.trending_down : Icons.trending_up,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
