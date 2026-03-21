import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
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
        label = "Thấp";
        break;
      case RiskLevel.moderate:
        bgColor = AppStateColors.warningBg;
        textColor = AppColors.warning;
        label = "Theo dõi";
        break;
      case RiskLevel.high:
        bgColor = AppStateColors.criticalBg;
        textColor = AppColors.critical;
        label = "Cao";
        break;
      case RiskLevel.critical:
        bgColor = AppColors.emergency;
        textColor = Colors.white;
        label = "Nguy hiểm";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
