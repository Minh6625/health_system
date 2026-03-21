import 'package:flutter/material.dart';

class StatusInsightBanner extends StatelessWidget {
  final bool isOnline;
  final int? batteryLevel;
  final DateTime? lastSeenAt;

  const StatusInsightBanner({
    super.key,
    required this.isOnline,
    required this.batteryLevel,
    this.lastSeenAt,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && (batteryLevel == null || batteryLevel! > 20)) {
      return const SizedBox.shrink(); // Healthy
    }

    final isLowBattery = batteryLevel != null && batteryLevel! <= 20;
    
    // Determine priority: Battery > Offline
    final title = isLowBattery ? 'Thiết bị cần chú ý' : 'Đã mất kết nối';
    final description = isLowBattery 
        ? 'Pin đang ở mức rất thấp ($batteryLevel%). Vui lòng sạc thiết bị để duy trì theo dõi liên tục.' 
        : 'Thiết bị đã ngắt kết nối $_lastSeenText. Hãy đảm bảo thiết bị đang bật và ở gần.';

    final icon = isLowBattery ? Icons.battery_alert_rounded : Icons.wifi_off_rounded;
    final color = const Color(0xFFD97706); // strong warning (amber-600 logic)
    final bgColor = const Color(0xFFFEF3C7); // amber-100 logic
    final borderColor = const Color(0xFFFDE68A); // amber-200 logic

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.9), // Darker text tint
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _lastSeenText {
    if (lastSeenAt == null) return 'từ lâu';
    final hours = DateTime.now().difference(lastSeenAt!).inHours;
    if (hours == 0) return 'gần đây';
    if (hours < 24) return 'khoảng $hours giờ trước';
    return 'từ ${DateTime.now().difference(lastSeenAt!).inDays} ngày trước';
  }
}
