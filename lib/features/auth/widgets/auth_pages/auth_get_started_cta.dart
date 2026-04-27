import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

/// "Bắt đầu ngay" pill-shaped CTA shown above the auth page indicator.
///
/// Stays purely presentational - the parent decides what `onTap` does
/// (typically `_pageController.animateToPage` to slide into the login form).
/// The fade is driven by `opacity`, so the parent can hide the CTA when
/// the user is no longer on the welcome page without disposing the widget.
class AuthGetStartedCta extends StatelessWidget {
  final VoidCallback onTap;
  final double opacity;

  const AuthGetStartedCta({
    super.key,
    required this.onTap,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: AppRadii.pillRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bắt đầu ngay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.bgSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: AppColors.bgSurface,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
