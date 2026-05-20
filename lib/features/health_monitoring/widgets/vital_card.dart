import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
import '../models/vital_signs.dart';
import 'animated_vital_value.dart';

class VitalCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final VitalStatus status;
  final VoidCallback? onTap;

  /// Optional sub-message rendered under the unit. Used by the Phase 2
  /// dashboard to disambiguate why a value is "—" — e.g. "Đang đợi đồng
  /// bộ", "Watch chưa cấp quyền", "Đã hơn 15 phút chưa cập nhật". Keep
  /// short (≤ 40 chars) so it fits the 2-line cap.
  final String? subtitle;

  const VitalCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
    this.onTap,
    this.subtitle,
  });

  Color _getBackgroundColor() {
    switch (status) {
      case VitalStatus.normal:
        return AppStateColors.successBg;
      case VitalStatus.warning:
        return AppStateColors.warningBg;
      case VitalStatus.critical:
        return AppStateColors.criticalBg;
      case VitalStatus.unknown:
        return AppColors.bgPrimary;
    }
  }

  Color _getIconColor() {
    switch (status) {
      case VitalStatus.normal:
        return AppColors.success;
      case VitalStatus.warning:
        return AppColors.warning;
      case VitalStatus.critical:
        return AppColors.critical;
      case VitalStatus.unknown:
        return AppColors.textSecondary;
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case VitalStatus.normal:
        return AppColors.success;
      case VitalStatus.warning:
        return AppColors.warning;
      case VitalStatus.critical:
        return AppColors.critical;
      case VitalStatus.unknown:
        return AppColors.strokeSoft;
    }
  }

  String _getStatusText() {
    switch (status) {
      case VitalStatus.normal:
        return 'Bình thường';
      case VitalStatus.warning:
        return 'Cảnh báo';
      case VitalStatus.critical:
        return 'Nguy hiểm';
      case VitalStatus.unknown:
        return 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.cardRadius,
      child: Container(
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: AppRadii.cardRadius,
          border: Border.all(
            color: _getBorderColor(),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getIconColor().withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: _getIconColor(),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.gapSm,
                    vertical: AppSpacing.gapXs,
                  ),
                  decoration: BoxDecoration(
                    color: _getIconColor().withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _getIconColor(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.gapMd),
            // Title
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.gapXs),
            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedVitalValue(
                      value: value,
                      color: _getIconColor(),
                      fontSize: 28,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.gapXs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            // Phase 2: optional sub-message that explains a missing value
            // (e.g. "Đang đợi đồng bộ"). Renders only when supplied so
            // existing call sites without a subtitle keep their layout.
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.gapXs),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
