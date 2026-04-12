import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';

/// A row of quick-access action buttons (History & Stats) at the bottom of
/// the Health Monitoring dashboard. Each button has a min-height of 56dp
/// to satisfy the accessibility touch-target requirement.
class QuickActionsPanel extends StatelessWidget {
  final VoidCallback? onHistoryTap;
  final VoidCallback? onStatsTap;

  const QuickActionsPanel({
    super.key,
    this.onHistoryTap,
    this.onStatsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hành động nhanh',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: AppSpacing.gapMd),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.history,
                label: 'Lịch sử',
                onTap: onHistoryTap,
              ),
            ),
            SizedBox(width: AppSpacing.gapMd),
            Expanded(
              child: _ActionButton(
                icon: Icons.analytics,
                label: 'Thống kê',
                onTap: onStatsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadii.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.gapLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.radiusMd),
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.brandPrimary, size: 28),
              SizedBox(height: AppSpacing.gapSm),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
