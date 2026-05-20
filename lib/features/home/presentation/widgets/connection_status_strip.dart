import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

enum DeviceConnectionUiState { connected, offline, notPaired }

class ConnectionStatusStrip extends StatelessWidget {
  final DeviceConnectionUiState deviceConnectionState;
  final int? batteryPercent;
  final String lastUpdatedLabel;
  final String? deviceName;
  final VoidCallback onTapDevice;

  const ConnectionStatusStrip({
    super.key,
    required this.deviceConnectionState,
    this.batteryPercent,
    required this.lastUpdatedLabel,
    this.deviceName,
    required this.onTapDevice,
  });

  @override
  Widget build(BuildContext context) {
    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (deviceConnectionState) {
      case DeviceConnectionUiState.connected:
        statusIcon = Icons.watch_rounded;
        statusColor = AppColors.success;
        // Phase 3: prefer the actual device name (Redmi Watch 3, Mi Band 8...)
        // so the dashboard never lies about which watch is feeding data.
        // Falls back to the legacy generic copy when the user has not
        // pinned a primary and DeviceProvider has not loaded yet.
        statusText = (deviceName != null && deviceName!.trim().isNotEmpty)
            ? deviceName!.trim()
            : 'Đồng hồ đang kết nối';
        break;
      case DeviceConnectionUiState.offline:
        statusIcon = Icons.watch_off_rounded;
        statusColor = AppColors.textSecondary;
        statusText = (deviceName != null && deviceName!.trim().isNotEmpty)
            ? '${deviceName!.trim()} · offline'
            : 'Đồng hồ offline';
        break;
      case DeviceConnectionUiState.notPaired:
        statusIcon = Icons.phonelink_erase_rounded;
        statusColor = AppColors.warning;
        statusText = 'Chưa kết nối đồng hồ';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapDevice,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(statusText, style: AppTextStyles.bodyMedium),
                    if (deviceConnectionState !=
                        DeviceConnectionUiState.connected) ...[
                      const SizedBox(height: 2),
                      Text(
                        lastUpdatedLabel,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (deviceConnectionState == DeviceConnectionUiState.connected &&
                  batteryPercent != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: AppRadii.pillRadius,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        batteryPercent! <= 20
                            ? Icons.battery_alert_rounded
                            : Icons.battery_full_rounded,
                        size: 14,
                        color: batteryPercent! <= 20
                            ? AppColors.emergency
                            : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$batteryPercent%',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.gapSm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
