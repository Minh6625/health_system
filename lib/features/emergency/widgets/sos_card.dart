import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:intl/intl.dart';

class SOSCard extends StatelessWidget {
  final SOSEventModel sos;
  final VoidCallback onTap;
  final VoidCallback onCallPressed;
  final VoidCallback onMapPressed;

  const SOSCard({
    super.key,
    required this.sos,
    required this.onTap,
    required this.onCallPressed,
    required this.onMapPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUrgent = sos.isActive;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapLg,
        vertical: AppSpacing.gapSm,
      ),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.critical.withValues(alpha: 0.15)
            : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(
          color: AppColors.strokeSoft.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUrgent
                ? AppColors.critical.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.gapLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(),
                SizedBox(width: AppSpacing.sectionGapSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sos.patient.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: AppSpacing.gapSm),
                          _buildActionButton(isUrgent),
                        ],
                      ),
                      SizedBox(height: AppSpacing.gapXs + 1),
                      _buildTriggerChip(),
                      SizedBox(height: AppSpacing.gapXs + 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: AppSpacing.gapXs),
                          Text(
                            _formatTimeAgo(sos.triggerTime),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.gapXs - 1),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: AppSpacing.gapXs),
                          Expanded(
                            child: Text(
                              sos.location.address ??
                                  (sos.location.latitude != null &&
                                          sos.location.longitude != null
                                      ? '${sos.location.latitude!.toStringAsFixed(4)}, ${sos.location.longitude!.toStringAsFixed(4)}'
                                      : 'Vị trí không xác định'),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Patient avatar
  Widget _buildAvatar() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.strokeSoft,
      ),
      child: ClipOval(
        child: sos.patient.photoUrl != null
            ? CachedNetworkImage(
                imageUrl: sos.patient.photoUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textSecondary,
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppColors.bgPrimary,
      child: Icon(Icons.person, size: 35, color: AppColors.textSecondary),
    );
  }

  /// Trigger type chip
  Widget _buildTriggerChip() {
    Color bgColor;
    Color textColor;
    String label;

    switch (sos.triggerType) {
      case 'fall_detected':
        bgColor = AppStateColors.criticalBg;
        textColor = AppColors.critical;
        label = 'Té ngã';
        break;
      case 'manual':
        bgColor = AppStateColors.warningBg;
        textColor = AppColors.warning;
        label = 'Thủ công';
        break;
      case 'vital_critical':
        bgColor = AppStateColors.criticalBg;
        textColor = AppColors.critical;
        label = 'Chỉ số nguy hiểm';
        break;
      default:
        bgColor = AppStateColors.infoBg;
        textColor = AppColors.info;
        label = 'SOS';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapSm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// Action button - compact badge
  Widget _buildActionButton(bool isUrgent) {
    if (isUrgent) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.gapSm + 2,
          vertical: AppSpacing.gapXs + 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.critical,
          borderRadius: BorderRadius.circular(AppRadii.radiusSm),
          boxShadow: [
            BoxShadow(
              color: AppColors.critical.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.bgSurface,
              size: 13,
            ),
            SizedBox(width: AppSpacing.gapXs + 1),
            Text(
              'KHẨN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.bgSurface,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.gapSm + 2,
          vertical: AppSpacing.gapXs + 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(AppRadii.radiusSm),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppColors.bgSurface,
              size: 13,
            ),
            SizedBox(width: AppSpacing.gapXs + 1),
            Text(
              'Hoàn tất',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.bgSurface,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
