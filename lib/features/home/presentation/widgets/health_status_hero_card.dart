import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

enum DashboardOverallStatus { normal, warning, critical, noDevice, offline }

class HealthStatusHeroCard extends StatelessWidget {
  final DashboardOverallStatus overallStatus;
  final String title;
  final String summary;
  final String? secondaryCtaLabel;
  final VoidCallback? onTapSecondaryCta;
  final bool showCallHelpCta;
  final VoidCallback? onTapCallHelp;

  const HealthStatusHeroCard({
    super.key,
    required this.overallStatus,
    required this.title,
    required this.summary,
    this.secondaryCtaLabel,
    this.onTapSecondaryCta,
    this.showCallHelpCta = false,
    this.onTapCallHelp,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color chipColor;
    Color chipTextColor;
    String chipLabel;

    IconData chipIcon;

    switch (overallStatus) {
      case DashboardOverallStatus.normal:
        bgColor = AppStateColors.successBg;
        chipColor = AppColors.success;
        chipTextColor = AppColors.bgSurface;
        chipLabel = 'Ổn định';
        chipIcon = Icons.check_circle_rounded;
        break;
      case DashboardOverallStatus.warning:
        bgColor = AppStateColors.warningBg;
        chipColor = AppColors.warning;
        chipTextColor =
            AppColors.textPrimary; // Keeping text dark on yellow for contrast
        chipLabel = 'Cảnh báo';
        chipIcon = Icons.warning_rounded;
        break;
      case DashboardOverallStatus.critical:
        bgColor = AppStateColors.criticalBg;
        chipColor = AppColors.emergency;
        chipTextColor = AppColors.bgSurface;
        chipLabel = 'Nguy hiểm';
        chipIcon = Icons.error_rounded;
        break;
      case DashboardOverallStatus.noDevice:
      case DashboardOverallStatus.offline:
        bgColor = AppStateColors.infoBg;
        chipColor = AppColors.info;
        chipTextColor = AppColors.bgSurface;
        chipLabel = overallStatus == DashboardOverallStatus.noDevice
            ? 'Chưa kết nối'
            : 'Ngoại tuyến';
        chipIcon = overallStatus == DashboardOverallStatus.noDevice
            ? Icons.watch_off_rounded
            : Icons.wifi_off_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sectionGapLg),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: AppRadii.pillRadius,
                  boxShadow: [
                    BoxShadow(
                      color: chipColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 16, color: chipTextColor),
                    const SizedBox(width: 6),
                    Text(
                      chipLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: chipTextColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            title,
            style: AppTextStyles.displayCompact.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            summary,
            style: AppTextStyles.body.copyWith(
              color: overallStatus == DashboardOverallStatus.critical
                  ? AppColors.emergency
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (secondaryCtaLabel != null || showCallHelpCta) ...[
            const SizedBox(height: AppSpacing.gapMd),
            Row(
              children: [
                if (secondaryCtaLabel != null && onTapSecondaryCta != null)
                  TextButton(
                    onPressed: onTapSecondaryCta,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          secondaryCtaLabel!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.brandPrimary,
                        ),
                      ],
                    ),
                  ),
                if (showCallHelpCta && onTapCallHelp != null) ...[
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: onTapCallHelp,
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Gọi trợ giúp ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                      foregroundColor: AppColors.bgSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.pillRadius,
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
