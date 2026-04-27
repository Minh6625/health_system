import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../utils/notification_severity.dart';
import 'notification_info_chip.dart';

/// Single notification card rendered inside the list `ListView.builder`.
///
/// Layout:
/// ```
/// ┌──────┬───────────────────────────────────────────┐
/// │      │ Title                          time-ago    │
/// │ Icon │ Message preview (max 2 lines)              │
/// │      │ [Severity pill]   [Mới]                    │
/// └──────┴───────────────────────────────────────────┘
/// ```
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
    final alertType = (item['alert_type'] as String?) ?? 'general';
    final severity = (item['severity'] as String?) ?? 'normal';
    final createdAt = notificationCreatedAt(item);
    final title = (item['title'] as String?) ?? 'Thông báo';
    final message = (item['message'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isRead ? AppColors.bgSurface : const Color(0xFFDDE8FA),
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
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
              borderRadius: BorderRadius.circular(AppRadii.radiusMd),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeadingIcon(alertType: alertType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (createdAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    notificationTimeAgoLabel(createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (message.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              NotificationInfoChip(
                                label: notificationSeverityLabel(severity),
                                color: notificationSeverityColor(
                                  severity,
                                ).withValues(alpha: 0.12),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square colored thumbnail rendered to the left of the body. The square
/// uses the alert-type's brand color so users can visually scan SOS / vital
/// / medication / system events without reading the chip text.
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.alertType});

  final String alertType;

  @override
  Widget build(BuildContext context) {
    final bg = notificationLeadingIconBg(alertType);
    final icon = notificationLeadingIcon(alertType);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: bg.withValues(alpha: 0.32)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: bg, size: 24),
    );
  }
}
