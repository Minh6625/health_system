import 'package:flutter/material.dart';
import 'package:healthguard/features/device/models/device_model.dart';
import 'package:healthguard/features/device/providers/device_status_detail_provider.dart';
import 'package:healthguard/features/device/screens/device_configure_screen.dart';
import 'package:healthguard/features/device/widgets/device_status/status_insight_banner.dart';
import 'package:healthguard/features/device/widgets/device_status/device_status_hero_card.dart';
import 'package:healthguard/features/device/widgets/device_status/device_info_section.dart';
import 'package:healthguard/features/device/widgets/device_status/primary_action_card.dart';
import 'package:healthguard/features/device/widgets/device_status/info_row.dart';
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Trạng thái thiết bị',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF12304A)),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF12304A)),
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<DeviceStatusDetailProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.device == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
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
            color: const Color(0xFF0F766E),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                DeviceStatusHeroCard(device: device),
                const SizedBox(height: 24),
                
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
                
                DeviceInfoSection(
                  title: 'Thông tin kỹ thuật',
                  children: [
                    InfoRow(label: 'Firmware', value: device.firmwareVersion ?? 'Chưa có'),
                    InfoRow(label: 'Serial', value: device.serialNumber ?? 'Chưa có'),
                    InfoRow(label: 'MAC', value: device.macAddress ?? 'Chưa có'),
                    InfoRow(
                      label: 'MQTT', 
                      value: device.mqttClientId != null ? '${device.mqttClientId!.substring(0, 8)}...' : 'Chưa có',
                      isLast: true,
                    ),
                  ],
                ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.do_not_disturb_alt_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Thiết bị không còn tồn tại',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF12304A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Có thể thiết bị đã bị xóa hoặc hủy kết nối.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5B7288)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quay lại danh sách', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DeviceStatusDetailProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF5B7288)),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF5B7288),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => provider.fetchDeviceDetail(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
