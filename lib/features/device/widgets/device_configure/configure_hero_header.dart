import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class ConfigureHeroHeader extends StatelessWidget {
  final DeviceModel device;

  const ConfigureHeroHeader({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isOnline ? AppColors.success : AppColors.textSecondary;
    final statusText = device.isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.gapMd),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.watch_rounded, size: 28, color: AppColors.brandPrimary),
          ),
          SizedBox(width: AppSpacing.sectionGapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: AppTextStyles.sectionTitle,
                ),
                SizedBox(height: AppSpacing.gapXs),
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
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
