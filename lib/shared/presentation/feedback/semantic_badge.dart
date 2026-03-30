import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum SemanticBadgeLevel { info, warning, critical }

class SemanticBadge extends StatelessWidget {
  final bool isDotOnly;
  final String? text;
  final SemanticBadgeLevel level;

  const SemanticBadge({
    super.key,
    this.isDotOnly = true,
    this.text,
    this.level = SemanticBadgeLevel.critical,
  });

  const SemanticBadge.dot({super.key, this.level = SemanticBadgeLevel.critical})
    : isDotOnly = true,
      text = null;

  const SemanticBadge.text(
    this.text, {
    super.key,
    this.level = SemanticBadgeLevel.critical,
  }) : isDotOnly = false;

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor = AppColors.bgSurface;

    switch (level) {
      case SemanticBadgeLevel.info:
        badgeColor = AppColors.info;
        break;
      case SemanticBadgeLevel.warning:
        badgeColor = AppColors.warning;
        // Adjust text color for warning if needed for contrast
        textColor = AppColors.textPrimary;
        break;
      case SemanticBadgeLevel.critical:
        badgeColor = AppColors.emergency;
        break;
    }

    if (isDotOnly) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: badgeColor,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bgSurface, width: 1.5),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: AppColors.bgSurface, width: 1.5),
      ),
      child: Text(
        text ?? '',
        style: AppTextStyles.caption.copyWith(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
