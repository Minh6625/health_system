import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

enum InlineStatusLevel { warning, offline }

class InlineStatusBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final InlineStatusLevel level;

  const InlineStatusBanner({
    super.key,
    required this.message,
    required this.icon,
    required this.level,
  });

  factory InlineStatusBanner.warning({required String message, Key? key}) {
    return InlineStatusBanner(
      key: key,
      message: message,
      icon: Icons.warning_amber_rounded,
      level: InlineStatusLevel.warning,
    );
  }

  factory InlineStatusBanner.offline({required String message, Key? key}) {
    return InlineStatusBanner(
      key: key,
      message: message,
      icon: Icons.cloud_off_rounded,
      level: InlineStatusLevel.offline,
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color contentColor;

    switch (level) {
      case InlineStatusLevel.warning:
        bgColor = AppStateColors.warningBg;
        contentColor = AppColors.warning;
        break;
      case InlineStatusLevel.offline:
        bgColor = AppStateColors.infoBg;
        contentColor = AppColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: contentColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
