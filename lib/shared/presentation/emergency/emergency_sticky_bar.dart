import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum EmergencyBarEmphasis { defaultLevel, heightened }

class EmergencyStickyBar extends StatelessWidget {
  final EmergencyBarEmphasis emphasis;
  final VoidCallback onPressed;

  const EmergencyStickyBar({
    super.key,
    this.emphasis = EmergencyBarEmphasis.defaultLevel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: EdgeInsets.only(
        left: AppSpacing.screenHorizontalPadding.horizontal / 2,
        right: AppSpacing.screenHorizontalPadding.horizontal / 2,
        top: 8,
        bottom: AppSpacing.stickyBottomActionGap,
      ),
      child: Material(
        color: AppColors.emergency,
        borderRadius: BorderRadius.circular(32),
        elevation: 4,
        shadowColor: AppColors.emergency.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            height: 60,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sos_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Gọi SOS khẩn cấp',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
