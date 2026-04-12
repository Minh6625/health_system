import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/screens/device_status_detail_screen.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class DevicePriorityCard extends StatelessWidget {
  final DeviceModel device;
  final bool needsAttention;
  final Function(DeviceModel, String) onActionSelected;
  final VoidCallback onRefreshRequested;

  const DevicePriorityCard({
    super.key,
    required this.device,
    required this.needsAttention,
    required this.onActionSelected,
    required this.onRefreshRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline = !device.isOnline;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        border: needsAttention
            ? Border.all(color: AppColors.warning, width: 1.5)
            : Border.all(color: AppColors.strokeSoft, width: 1),
        boxShadow: needsAttention
            ? [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : AppShadows.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.radiusXl),
          onTap: () => _handleDeviceTap(context),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  device.displayName,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: AppSpacing.gapSm),
                              _buildStatusBadge(isOffline),
                            ],
                          ),
                          SizedBox(height: AppSpacing.gapXs + 2),
                          Text(
                            _buildSubtitle(),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Kebab menu
                    PopupMenuButton<String>(
                      onSelected: (value) => onActionSelected(device, value),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(device.isActive ? 'Tắt thiết bị' : 'Kích hoạt'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa thiết bị', style: TextStyle(color: AppColors.critical)),
                        ),
                      ],
                      icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.gapLg),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildInfoPill(
                      Icons.battery_6_bar_rounded,
                      _batteryText(),
                      isWarning: _isBatteryLow(),
                    ),
                    if (device.signalStrength != null)
                      _buildInfoPill(
                        Icons.network_cell_rounded,
                        'RSSI ${device.signalStrength}',
                        isWarning: isOffline,
                      ),
                    _buildActionPill(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeviceTap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceStatusDetailScreen(
          deviceId: device.id,
          initialDevice: device,
        ),
      ),
    );
    onRefreshRequested();
  }

  String _buildSubtitle() {
    final List<String> parts = [];
    if (_isBatteryLow()) parts.add('Pin yếu');
    
    // Sync time
    if (device.lastSyncAt == null) {
      parts.add('Chưa đồng bộ');
    } else {
      final diff = DateTime.now().difference(device.lastSyncAt!);
      if (diff.inHours >= 24) {
        parts.add('Mất đồng bộ');
      } else if (diff.inMinutes < 60) {
        parts.add('Đồng bộ vài phút trước');
      } else {
        parts.add('Đồng bộ ${diff.inHours}h trước');
      }
    }
    
    if (parts.isEmpty) return 'Hoạt động ổn định';
    return parts.join(' • ');
  }

  bool _isBatteryLow() => device.batteryLevel != null && device.batteryLevel! <= 20;

  String _batteryText() {
    if (device.batteryLevel == null) return 'Pin --';
    return 'Pin ${device.batteryLevel}%';
  }

  Widget _buildStatusBadge(bool isOffline) {
    final color = isOffline ? AppColors.textSecondary : AppColors.success;
    final label = isOffline ? 'Offline' : 'Online';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String label, {bool isWarning = false}) {
    final color = isWarning ? AppColors.warning : AppColors.textSecondary;
    final bgColor = isWarning ? AppStateColors.warningBg : AppColors.bgPrimary;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: AppSpacing.gapXs + 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            needsAttention ? 'Kiểm tra ngay' : 'Chi tiết',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: needsAttention ? AppColors.warning : AppColors.brandPrimary,
            ),
          ),
          SizedBox(width: AppSpacing.gapXs),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: needsAttention ? AppColors.warning : AppColors.brandPrimary,
          ),
        ],
      ),
    );
  }
}
