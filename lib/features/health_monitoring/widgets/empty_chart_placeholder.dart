import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';

class EmptyChartPlaceholder extends StatelessWidget {
  final String message;

  const EmptyChartPlaceholder({
    super.key,
    this.message = 'Chưa có dữ liệu',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        border: Border.all(color: AppColors.strokeSoft, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppSpacing.gapLg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
