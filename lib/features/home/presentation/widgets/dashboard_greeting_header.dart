import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DashboardGreetingHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final String latestUpdatedLabel;
  final bool hasUnreadNotifications;
  final VoidCallback onTapNotifications;

  const DashboardGreetingHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    required this.latestUpdatedLabel,
    this.hasUnreadNotifications = false,
    required this.onTapNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sectionGapMd,
        bottom: AppSpacing.sectionGapMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.strokeSoft,
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSecondary,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào $displayName',
                  style: AppTextStyles.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.gapXs),
                Text(
                  latestUpdatedLabel,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: onTapNotifications,
              ),
              if (hasUnreadNotifications)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.emergency,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgPrimary, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
