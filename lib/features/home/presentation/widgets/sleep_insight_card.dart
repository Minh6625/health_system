import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';

class SleepInsightCard extends StatelessWidget {
  final int sleepDurationMinutes;
  final String durationLabel;
  final String insightSummary;
  final VoidCallback onTap;

  const SleepInsightCard({
    super.key,
    required this.sleepDurationMinutes,
    required this.durationLabel,
    required this.insightSummary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color durationColor;
    if (sleepDurationMinutes >= 8 * 60) {
      durationColor = AppColors.success; // Ngủ ngon -> Xanh lá
    } else if (sleepDurationMinutes >= 6 * 60) {
      durationColor = AppColors.warning; // Thiếu ngủ -> Cam
    } else if (sleepDurationMinutes >= 4 * 60) {
      durationColor = AppColors.warning; // Nặng -> Vàng
    } else {
      durationColor = AppColors.emergency; // Mất ngủ -> Đỏ
    }
    
    // Format duration label from '7h20' to '7 giờ 20 phút' (assumes durationLabel format or calculate from minutes)
    final hours = sleepDurationMinutes ~/ 60;
    final minutes = sleepDurationMinutes % 60;
    final formattedDuration = '$hours giờ $minutes phút';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          width: double.infinity,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF131A2F), Color(0xFF1C274B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadii.cardRadius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF131A2F).withValues(alpha: 0.15),
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
                  const Icon(Icons.bed_rounded, color: Color(0xFFD8B4FE), size: 24),
                  const SizedBox(width: AppSpacing.gapSm),
                  Text(
                    'Giấc ngủ',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFFD8B4FE), // Light purple
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
                  // Left side: Large Illustration (Lottie)
                  Expanded(
                    flex: 2,
                    child: Transform.scale(
                      scale: 1.4, // Cắt bớt khoảng trống thừa
                      child: Lottie.asset(
                        'assets/lottie/sleep_animation.json',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            height: 100,
                            child: Icon(Icons.nightlight_round, size: 64, color: Colors.white24),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapMd),
                  
                  // Right side: Info Section
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Bạn đã ngủ',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.gapXs),
                        // Large number
                        Text(
                          formattedDuration,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.displayCompact.copyWith(
                            color: durationColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.gapSm),
                        // Summary
                        Text(
                          insightSummary,
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
              const SizedBox(height: AppSpacing.sectionGapMd),

              // Divider
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              const SizedBox(height: AppSpacing.gapMd),

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
                      'Xem chi tiết',
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

