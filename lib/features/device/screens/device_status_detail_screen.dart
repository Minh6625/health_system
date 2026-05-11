import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_status_detail_provider.dart';
import 'package:healthguard/features/device/screens/device_configure_screen.dart';
import 'package:healthguard/features/device/widgets/device_status/status_insight_banner.dart';
import 'package:healthguard/features/device/widgets/device_status/device_status_hero_card.dart';
import 'package:healthguard/features/device/widgets/device_status/device_info_section.dart';
import 'package:healthguard/features/device/widgets/device_status/primary_action_card.dart';
import 'package:healthguard/features/device/widgets/device_status/info_row.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:provider/provider.dart';

class DeviceStatusDetailScreen extends StatelessWidget {
  final int deviceId;
  final DeviceModel? initialDevice;

  const DeviceStatusDetailScreen({
    super.key,
    required this.deviceId,
    this.initialDevice,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = DeviceStatusDetailProvider(deviceId: deviceId);
        if (initialDevice != null) {
          provider.syncWithExisting(initialDevice!);
        }
        return provider;
      },
      child: const _DeviceStatusDetailView(),
    );
  }
}

class _DeviceStatusDetailView extends StatelessWidget {
  const _DeviceStatusDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Trạng thái thiết bị',
          style: AppTextStyles.sectionTitle,
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<DeviceStatusDetailProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.device == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandPrimary));
          }

          if (provider.errorMessage != null && provider.device == null) {
            if (provider.errorMessage!.contains('không còn tồn tại')) {
              return _buildNotFoundState(context);
            }
            return _buildErrorState(context, provider);
          }

          final device = provider.device!;

          return RefreshIndicator(
            onRefresh: () => provider.fetchDeviceDetail(),
            color: AppColors.brandPrimary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapMd, vertical: AppSpacing.sectionGapLg),
              children: [
                DeviceStatusHeroCard(device: device),
                const SizedBox(height: AppSpacing.sectionGapXl),
                
                StatusInsightBanner(
                  isOnline: device.isOnline,
                  batteryLevel: device.batteryLevel,
                  lastSeenAt: device.lastSeenAt,
                ),
                
                DeviceInfoSection(
                  title: 'Thông tin chung',
                  children: [
                    InfoRow(label: 'Tên thiết bị', value: device.displayName),
                    InfoRow(label: 'Loại', value: device.typeLabel),
                    InfoRow(label: 'Kết nối', value: device.isOnline ? 'Đang kết nối' : 'Mất kết nối'),
                    InfoRow(
                      label: 'Đồng bộ lần cuối', 
                      value: _timeText(device.lastSyncAt),
                      isLast: true,
                    ),
                  ],
                ),
                
                PrimaryActionCard(
                  label: 'Cấu hình thiết bị',
                  onPressed: () => _navigateToConfigure(context, device),
                ),

                // Bug 1 (QA M-12): the technical info card used to render
                // four rows that all said "Chưa có" for devices paired via
                // BLE (firmware/MAC/serial/MQTT not yet reported), which
                // looked like a broken screen. We now build the row list
                // conditionally and skip the section entirely when the
                // device has nothing to show.
                _buildTechnicalInfoSection(device),
                const SizedBox(height: 48), // Bottom padding
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionGapXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.do_not_disturb_alt_rounded, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.sectionGapMd),
            Text(
              'Thiết bị không còn tồn tại',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              'Có thể thiết bị đã bị xóa hoặc hủy kết nối.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapXl, vertical: AppSpacing.gapMd),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
              ),
              child: Text('Quay lại danh sách', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DeviceStatusDetailProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sectionGapXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.critical),
            const SizedBox(height: AppSpacing.sectionGapMd),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapXl, vertical: AppSpacing.gapMd),
                  ),
                  child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: AppSpacing.sectionGapMd),
                ElevatedButton.icon(
                  onPressed: () => provider.fetchDeviceDetail(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapXl, vertical: AppSpacing.gapMd),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToConfigure(BuildContext context, DeviceModel device) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceConfigureScreen(device: device),
      ),
    );

    if (result == true) {
      if (context.mounted) {
        context.read<DeviceStatusDetailProvider>().fetchDeviceDetail();
      }
    } else if (result == 'deleted') {
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  String _timeText(DateTime? time) {
    if (time == null) return 'Chưa có';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  /// Build the "Thông tin kỹ thuật" card only with rows that have a real
  /// value. When every technical field is null (typical for a freshly
  /// BLE-paired device that hasn't reported telemetry yet), we hide the
  /// whole card so the user doesn't see a stack of "Chưa có" placeholders
  /// that read like a broken screen.
  Widget _buildTechnicalInfoSection(DeviceModel device) {
    final entries = <MapEntry<String, String>>[];
    if (device.firmwareVersion != null &&
        device.firmwareVersion!.trim().isNotEmpty) {
      entries.add(MapEntry('Firmware', device.firmwareVersion!));
    }
    if (device.serialNumber != null &&
        device.serialNumber!.trim().isNotEmpty) {
      entries.add(MapEntry('Serial', device.serialNumber!));
    }
    if (device.macAddress != null && device.macAddress!.trim().isNotEmpty) {
      entries.add(MapEntry('MAC', device.macAddress!));
    }
    if (device.mqttClientId != null &&
        device.mqttClientId!.trim().isNotEmpty) {
      // Same truncation as before: backend MQTT client IDs are long opaque
      // strings, the user only needs the prefix to confirm identity.
      final mqtt = device.mqttClientId!;
      final preview = mqtt.length > 8 ? '${mqtt.substring(0, 8)}...' : mqtt;
      entries.add(MapEntry('MQTT', preview));
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return DeviceInfoSection(
      title: 'Thông tin kỹ thuật',
      children: [
        for (var i = 0; i < entries.length; i++)
          InfoRow(
            label: entries[i].key,
            value: entries[i].value,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}
