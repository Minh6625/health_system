import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DashboardSecondaryLinks extends StatelessWidget {
  final VoidCallback onTapHistory;
  final VoidCallback onTapDeviceSettings;
  final VoidCallback onTapNotifications;

  const DashboardSecondaryLinks({
    super.key,
    required this.onTapHistory,
    required this.onTapDeviceSettings,
    required this.onTapNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.gapSm),
          child: Text('Thao tác nhanh', style: AppTextStyles.sectionTitle),
        ),
        _buildLinkItem(
          icon: Icons.history_rounded,
          label: 'Lịch sử chỉ số',
          onTap: onTapHistory,
        ),
        _buildLinkItem(
          icon: Icons.watch_rounded,
          label: 'Quản lý thiết bị',
          onTap: onTapDeviceSettings,
        ),
        _buildLinkItem(
          icon: Icons.notifications_none_rounded,
          label: 'Tất cả thông báo',
          onTap: onTapNotifications,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildLinkItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.textSecondary),
          title: Text(label, style: AppTextStyles.bodyMedium),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.strokeSoft,
          ),
          onTap: onTap,
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 1, color: AppColors.strokeSoft),
      ],
    );
  }
}
