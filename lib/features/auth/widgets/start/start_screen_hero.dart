import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

/// Hero section của StartScreen: Logo chính với hiệu ứng "breathing" (phóng to thu nhỏ liên tục).
class StartScreenHero extends StatelessWidget {
  const StartScreenHero({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final logoHeight = isSmallScreen ? 200.0 : 280.0;
    final logoPadding = isSmallScreen ? 12.0 : 20.0;

    return Container(
      height: logoHeight,
      padding: EdgeInsets.all(logoPadding),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    )
        // Entrance: fade-in + slide up
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: 200.ms)
        // Continuous breathing: scale up + down, reverse loop
        .then(delay: 200.ms)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.04, 1.04),
          duration: 2000.ms,
          curve: Curves.easeInOut,
        );
  }
}
