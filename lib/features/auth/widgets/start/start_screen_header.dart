import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

/// Header của StartScreen: Chỉ hiển thị Language button ở góc phải.
/// Logo bên trái đã bỏ vì trùng lặp với hero logo bên dưới.
class StartScreenHeader extends StatelessWidget {
  const StartScreenHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final padding = isSmallScreen ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Language Button — "🌐 VN" style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSurface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadii.radiusXl),
              border: Border.all(
                color: AppColors.strokeSoft,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.language, color: AppColors.textSecondary, size: 16),
                SizedBox(width: 6),
                Text(
                  'VN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: -0.3, end: 0, duration: 400.ms, delay: 100.ms);
  }
}
