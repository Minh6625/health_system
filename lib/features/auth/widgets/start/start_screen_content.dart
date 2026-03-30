import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/core/constants/app_colors.dart';

/// Content section của StartScreen: Tiêu đề, tagline, mô tả — với staggered slide-up + fade-in.
class StartScreenContent extends StatelessWidget {
  const StartScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final titleFontSize = isSmallScreen ? 32.0 : 40.0;
    final subtitleFontSize = isSmallScreen ? 18.0 : 20.0;
    final bodyFontSize = isSmallScreen ? 14.0 : 16.0;
    final spacing3 = isSmallScreen ? 12.0 : 24.0;
    final spacing4 = isSmallScreen ? 8.0 : 16.0;

    return Column(
      children: [
        // Title — slides up + fades in first
        Text(
          'HealthGuard',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
                fontSize: titleFontSize,
                letterSpacing: -0.5,
              ),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: 500.ms)
            .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 500.ms),

        SizedBox(height: spacing3),

        // Subtitle — staggered, appears after title
        Text(
          'Chăm sóc sức khỏe gia đình bạn',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: subtitleFontSize,
              ),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: 700.ms)
            .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 700.ms),

        SizedBox(height: spacing4),

        // Body — staggered, appears last
        Text(
          'Theo dõi chỉ số từ smartwatch.\nCảnh báo sớm đột quỵ & té ngã.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                fontSize: bodyFontSize,
                height: 1.5,
              ),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: 900.ms)
            .slideY(begin: 0.3, end: 0, duration: 500.ms, delay: 900.ms),
      ],
    );
  }
}
