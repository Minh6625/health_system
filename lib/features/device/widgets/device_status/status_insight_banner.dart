import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

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

    final icon =
        isLowBattery ? Icons.battery_alert_rounded : Icons.wifi_off_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sectionGapXl),
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.warning, size: 24),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapXs),
                Text(
                  description,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.warning.withValues(alpha: 0.8),
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
