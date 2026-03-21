import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';

class DeviceStatusHeroCard extends StatelessWidget {
  final DeviceModel device;

  const DeviceStatusHeroCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF12304A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.typeLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF5B7288),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6FFFB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.watch_rounded, size: 32, color: Color(0xFF0F766E)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                device.batteryLevel != null ? 'Pin ${device.batteryLevel}%' : 'Pin --',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12304A),
                  height: 1.0,
                ),
              ),
              const Spacer(),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 16),
          _buildSyncInfoRow(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isOnline = device.isOnline;
    final color = isOnline ? const Color(0xFF0F9D7A) : const Color(0xFF94A3B8);
    final bgColor = isOnline ? const Color(0xFFE6FFFB) : const Color(0xFFF1F5F9);
    final text = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.check_circle_rounded : Icons.offline_bolt_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSyncInfoRow() {
    final timeStr = _timeText(device.lastSyncAt);
    return Row(
      children: [
        const Icon(Icons.sync, size: 16, color: Color(0xFF5B7288)),
        const SizedBox(width: 6),
        Text(
          'Đồng bộ: $timeStr',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF5B7288),
          ),
        ),
      ],
    );
  }

  String _timeText(DateTime? time) {
    if (time == null) return 'Chưa có';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}
