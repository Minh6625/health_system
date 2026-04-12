import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';

/// Status badge for SOS events
class StatusBadge extends StatelessWidget {
  final String status; // 'active' | 'resolved'

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionGapSm,
        vertical: AppSpacing.gapXs + 2,
      ),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  AppColors.critical,
                  AppColors.critical.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : AppColors.success,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.bgSurface,
              size: 14,
            ),
          if (isActive) SizedBox(width: AppSpacing.gapXs),
          Text(
            isActive ? 'Khẩn cấp' : 'Đã xử lý',
            style: TextStyle(
              color: AppColors.bgSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
