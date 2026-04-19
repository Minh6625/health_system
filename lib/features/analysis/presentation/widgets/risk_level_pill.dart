import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_entity.dart';

class RiskLevelPill extends StatelessWidget {
  final RiskLevel level;

  const RiskLevelPill({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (level) {
      case RiskLevel.low:
        bgColor = AppStateColors.successBg;
        textColor = AppColors.success;
        label = "Ổn định";
        break;
      case RiskLevel.medium:
        bgColor = AppStateColors.warningBg;
        textColor = AppColors.warning;
        label = "Cần theo dõi";
        break;
      case RiskLevel.critical:
        bgColor = AppColors.emergency;
        textColor = AppColors.bgSurface;
        label = "Nguy hiểm";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gapMd,
        vertical: AppSpacing.gapXs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.pillRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
