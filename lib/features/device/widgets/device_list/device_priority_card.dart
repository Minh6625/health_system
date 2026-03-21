import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/screens/device_status_detail_screen.dart';

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: needsAttention
            ? Border.all(color: const Color(0xFFF2A93B), width: 1.5)
            : Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          if (needsAttention)
            const BoxShadow(
              color: Color(0x1AF2A93B),
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          else
            const BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
                                    color: Color(0xFF12304A), // text.primary
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(isOffline),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _buildSubtitle(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF5B7288), // text.secondary
                              fontWeight: FontWeight.w400,
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
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa thiết bị', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
    final color = isOffline ? const Color(0xFF94A3B8) : const Color(0xFF0F9D7A); // offline vs success
    final label = isOffline ? 'Offline' : 'Online';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
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
    final color = isWarning ? const Color(0xFFD97706) : const Color(0xFF5B7288);
    final bgColor = isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFF4F7FB);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: needsAttention ? const Color(0xFFD97706) : const Color(0xFF0F766E),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: needsAttention ? const Color(0xFFD97706) : const Color(0xFF0F766E),
          ),
        ],
      ),
    );
  }
}
