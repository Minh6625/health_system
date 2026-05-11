import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _RippleRing(
                    controller: _controller,
                    delay: 0.0,
                    color: AppColors.brandPrimary,
                  ),
                  _RippleRing(
                    controller: _controller,
                    delay: 0.33,
                    color: AppColors.brandPrimary,
                  ),
                  _RippleRing(
                    controller: _controller,
                    delay: 0.66,
                    color: AppColors.brandPrimary,
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPrimary.withOpacity(0.18),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_rmbg.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Health Guard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Theo dõi sức khỏe thông minh',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  const _RippleRing({
    required this.controller,
    required this.delay,
    required this.color,
  });

  final AnimationController controller;
  final double delay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = ((controller.value - delay + 1.0) % 1.0);
        final eased = Curves.easeOut.transform(t);
        final scale = 0.35 + 1.0 * eased;
        final opacity = (1.0 - eased).clamp(0.0, 1.0) * 0.45;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(opacity),
                width: 2.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
