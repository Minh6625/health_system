import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

enum RiskVisualState { low, moderate, high }

class RiskInsightCard extends StatelessWidget {
  final String scoreLabel;
  final String levelLabel;
  final String summary;
  final RiskVisualState riskVisualState;
  final VoidCallback onTap;

  const RiskInsightCard({
    super.key,
    required this.scoreLabel,
    required this.levelLabel,
    required this.summary,
    required this.riskVisualState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    switch (riskVisualState) {
      case RiskVisualState.low:
        scoreColor = AppColors.success;
        break;
      case RiskVisualState.moderate:
        scoreColor = Colors.orange;
        break;
      case RiskVisualState.high:
        scoreColor = AppColors.emergency;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapLg, vertical: AppSpacing.gapMd),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D253F), Color(0xFF163E57)], // Medical teal/dark blue tones
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.cardRadius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D253F).withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_rounded, color: Color(0xFF81E6D9), size: 24),
                  const SizedBox(width: AppSpacing.gapSm),
                  Text(
                    'Sức khoẻ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF81E6D9), // Light blue-green / teal
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapLg),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Lottie.asset(
                        'assets/lottie/health_animation.json',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.medical_services_rounded,
                          size: 64,
                          color: Color(0xFF81E6D9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapSm), // Reduced from gapMd
                  
                  // Right side: Info Section
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Điểm sức khoẻ hôm nay',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Large number
                        Text(
                          scoreLabel,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.displayCompact.copyWith(
                            color: scoreColor,
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Summary
                        Text(
                          summary,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapLg), // Reduced from sectionGapMd to tighten space before divider

              // Divider
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              const SizedBox(height: AppSpacing.gapSm),

              // Footer
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.gapSm),
                    Text(
                      'Xem lịch sử',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
