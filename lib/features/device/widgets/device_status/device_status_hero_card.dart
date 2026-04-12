import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class DeviceStatusHeroCard extends StatelessWidget {
  final DeviceModel device;

  const DeviceStatusHeroCard({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sectionGapXl),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        border: Border.all(color: AppColors.strokeSoft),
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
                      style: AppTextStyles.displayCompact,
                    ),
                    SizedBox(height: AppSpacing.gapXs),
                    Text(
                      device.typeLabel,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.watch_rounded, size: 32, color: AppColors.brandPrimary),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sectionGapXl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                device.batteryLevel != null ? 'Pin ${device.batteryLevel}%' : 'Pin --',
                style: AppTextStyles.vitalValue,
              ),
              const Spacer(),
              _buildStatusBadge(),
            ],
          ),
          SizedBox(height: AppSpacing.gapLg),
          _buildSyncInfoRow(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isOnline = device.isOnline;
    final color = isOnline ? AppColors.success : AppColors.textSecondary;
    final bgColor = isOnline ? AppColors.bgElevated : const Color(0xFFF1F5F9);
    final text = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.check_circle_rounded : Icons.offline_bolt_rounded, size: 16, color: color),
          SizedBox(width: AppSpacing.gapXs),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSyncInfoRow() {
    final timeStr = _timeText(device.lastSyncAt);
    return Row(
      children: [
        Icon(Icons.sync, size: 16, color: AppColors.textSecondary),
        SizedBox(width: AppSpacing.gapXs + 2),
        Text(
          'Đồng bộ: $timeStr',
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
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
