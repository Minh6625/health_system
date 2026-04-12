import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

/// Footer của StartScreen: Nút "Bắt đầu ngay" pulsing glow + sliding arrow icon + Trust indicators.
/// Chỉ hiển thị khi màn hình KHÔNG nằm trong PageView (`isInPageView == false`).
class StartScreenFooter extends StatelessWidget {
  final VoidCallback onGetStarted;

  const StartScreenFooter({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final buttonHeight = isSmallScreen ? 52.0 : 60.0;
    final trustFontSize = isSmallScreen ? 10.0 : 11.0;
    final badgeFontSize = isSmallScreen ? 11.0 : 12.0;
    final dividerSpacing = isSmallScreen ? 16.0 : 24.0;
    final trustSpacing = isSmallScreen ? 12.0 : 20.0;
    final bottomSpacing = isSmallScreen ? 16.0 : 24.0;

    return Column(
      children: [
        // Primary CTA Button — entrance animation
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton(
            onPressed: onGetStarted,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: AppColors.brandPrimary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Bắt đầu ngay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                // Sliding arrow icon — loops horizontally
                const Icon(Icons.arrow_forward, size: 24, color: Colors.white)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideX(
                      begin: 0,
                      end: 0.25,
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .shimmer(
              duration: 1800.ms,
              delay: 1600.ms,
              color: Colors.white.withValues(alpha: 0.15),
            ),
        )
            // Entrance fade+slide
            .animate()
            .fadeIn(duration: 600.ms, delay: 500.ms)
            .slideY(begin: 0.5, end: 0, duration: 600.ms, curve: Curves.easeOut, delay: 500.ms),

        SizedBox(height: dividerSpacing),

        // Trust Divider
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.strokeSoft)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'TIN CẬY & BẢO MẬT',
                style: TextStyle(
                  fontSize: trustFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.strokeSoft)),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 1300.ms),

        SizedBox(height: trustSpacing),

        // Trust Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrustBadge(
              icon: Icons.verified_user,
              label: 'Mã hóa đầu cuối',
              fontSize: badgeFontSize,
            ),
            const SizedBox(width: 24),
            _TrustBadge(
              icon: Icons.notifications_active,
              label: 'Hỗ trợ 24/7',
              fontSize: badgeFontSize,
            ),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 1400.ms),

        SizedBox(height: bottomSpacing),
      ],
    );
  }
}

/// Private helper widget: một badge tin cậy nhỏ (icon + label).
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final double fontSize;

  const _TrustBadge({
    required this.icon,
    required this.label,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brandPrimary, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
