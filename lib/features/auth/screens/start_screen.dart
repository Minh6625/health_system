import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/routes/app_router.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // White background
          Container(color: Colors.white),

          // Top image (logo.png) - 55% of screen with shadow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.55,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.13),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          // Bottom blue section - overlaps image by ~25%
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.36,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0),
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primary.withValues(alpha: 0.75),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Text section
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chăm sóc sức khỏe gia đình bạn',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'HealthGuard',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 50,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          Text(
                            'Theo dõi chỉ số từ smartwatch',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cảnh báo sớm đột quỵ & té ngã',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w400,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Button section
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryLight,
                          Colors.blue[700] ?? AppColors.primary,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openLogin(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Center(
                          child: Text(
                            'Bắt đầu ngay',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ),
                      ),
                    ),
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
