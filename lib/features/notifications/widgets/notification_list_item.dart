import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../utils/notification_severity.dart';
import 'notification_info_chip.dart';

/// Single notification card rendered inside the list `ListView.builder`.
///
/// Visual states:
/// - Unread: tinted background + colored stripe on the left + "Mới" chip.
/// - Read: white background, no stripe, no "Mới" chip.
class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = item['is_read'] == true;
    final type = (item['alert_type'] as String?) ?? 'general';
    final severity = (item['severity'] as String?) ?? 'normal';
    final createdAt = notificationCreatedAt(item);

    return Transform.translate(
      offset: Offset(0, isRead ? 0 : -2),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isRead ? AppColors.bgSurface : const Color(0xFFDDE8FA),
          borderRadius: BorderRadius.circular(AppRadii.radiusSm),
          border: Border.all(color: AppColors.strokeSoft, width: 1),
          boxShadow: [
            BoxShadow(
              color: isRead
                  ? Colors.black.withValues(alpha: 0.03)
                  : AppColors.brandPrimary.withValues(alpha: 0.14),
              blurRadius: isRead ? 8 : 12,
              offset: Offset(0, isRead ? 2 : 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (!isRead)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: AppColors.info),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: notificationSeverityColor(severity),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (item['title'] as String?) ?? 'Thông báo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (createdAt != null)
                            Text(
                              notificationTimeAgoLabel(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (item['message'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          NotificationInfoChip(
                            label: notificationAlertTypeLabel(type),
                            color: notificationTypeChipColor(type),
                          ),
                          NotificationInfoChip(
                            label: notificationSeverityLabel(severity),
                            color: AppColors.bgPrimary,
                          ),
                          if (!isRead)
                            const NotificationInfoChip(
                              label: 'Mới',
                              color: AppStateColors.infoBg,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
