import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';

class ConfigureHeroHeader extends StatelessWidget {
  final DeviceModel device;

  const ConfigureHeroHeader({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isOnline ? const Color(0xFF0F9D7A) : const Color(0xFF94A3B8);
    final statusText = device.isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFE6FFFB), // brand.soft
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.watch_rounded, size: 28, color: Color(0xFF0F766E)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12304A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$statusText • ${_timeText(device.lastSyncAt)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B7288),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeText(DateTime? time) {
    if (time == null) return 'Chưa có';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Đồng bộ vừa xong';
    if (diff.inMinutes < 60) return 'Đồng bộ ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Đồng bộ ${diff.inHours} giờ trước';
    return 'Đồng bộ ${diff.inDays} ngày trước';
  }
}
