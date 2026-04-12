import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';

/// A full-width banner card that replaces [QuickActionsPanel].
///
/// Design goal (from Plan §3): One wide, visually distinct card with a
/// subtle gradient and a large calendar/chart icon.  Min-height 72dp so
/// elderly users can tap it reliably.  Tapping navigates to the consolidated
/// Health Report screen (Timeline + Trends).
class HealthReportBanner extends StatelessWidget {
  /// Called when the user taps the banner.
  final VoidCallback? onTap;

  const HealthReportBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Báo cáo và nhật ký sức khoẻ — xem lịch sử và xu hướng',
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          splashColor: AppColors.brandPrimary.withValues(alpha: 0.15),
          highlightColor: AppColors.brandPrimary.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brandPrimary,
                  AppColors.brandPrimary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: AppRadii.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sectionGapXl.toDouble(),
                  vertical: AppSpacing.gapLg,
                ),
                child: Row(
                  children: [
                    // Leading icon cluster
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sectionGapSm.toDouble()),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                      ),
                      child: const Icon(
                        Icons.insert_chart_outlined_rounded,
                        size: 32,
                        color: AppColors.bgSurface,
                      ),
                    ),
                    SizedBox(width: AppSpacing.gapLg),

                    // Text block
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Báo cáo & Nhật ký sức khoẻ',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.bgSurface,
                            ),
                          ),
                          SizedBox(height: AppSpacing.gapXs),
                          Text(
                            'Xem lịch sử đo, xu hướng và thống kê',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.bgSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Trailing chevron
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: AppColors.bgSurface.withValues(alpha: 0.80),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
