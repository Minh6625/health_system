import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/ble_service.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../mock/device_mock_data.dart';
import '../../providers/device_connect_provider.dart';

/// Real-time BLE scan UI for Phase 1 of the Redmi Watch 3 integration.
///
/// Pre-Phase-1 this widget rendered a fake QR finder with a 2.5s timer. It
/// is now driven entirely by [DeviceConnectProvider]: live scan results
/// populate a list, [BleFailureReason] errors map to actionable CTAs, and
/// the legacy mock branch is kept reachable for emulator builds via
/// [DeviceMockConfig.useMockData].
class DeviceQrScanStep extends StatelessWidget {
  const DeviceQrScanStep({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sectionGapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (DeviceMockConfig.useMockData)
            const _MockBanner()
          else
            const _LiveScanHeader(),
          SizedBox(height: AppSpacing.sectionGapMd),
          Text(
            DeviceMockConfig.useMockData
                ? 'Đang quét (chế độ mô phỏng)'
                : 'Đang quét thiết bị BLE',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            'Đưa đồng hồ Redmi Watch 3 lại gần điện thoại. '
            'Đảm bảo đồng hồ chưa được ghép nối với app khác.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sectionGapLg),
          Expanded(child: _ScanBody(provider: provider)),
        ],
      ),
    );
  }
}

class _LiveScanHeader extends StatelessWidget {
  const _LiveScanHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.brandPrimary,
          ),
        ),
        SizedBox(width: AppSpacing.gapSm),
        Expanded(
          child: Text(
            'Đang quét sóng BLE quanh đây (tối đa 30 giây)...',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MockBanner extends StatelessWidget {
  const _MockBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.gapSm),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: AppColors.warning, size: 20),
          SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: Text(
              'Chế độ mô phỏng đang bật (DeviceMockConfig.useMockData = true). '
              'Đang hiển thị danh sách BLE giả để chạy trên emulator.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanBody extends StatelessWidget {
  final DeviceConnectProvider provider;
  const _ScanBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.state == DeviceConnectState.error) {
      return _ScanErrorView(
        message: provider.errorMessage ?? 'Có lỗi khi quét BLE.',
        reason: provider.errorReason,
        onRetry: () => provider.openQrScanner(),
      );
    }

    final devices = provider.discovered;
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_searching_rounded,
                size: 64, color: AppColors.brandPrimary),
            SizedBox(height: AppSpacing.gapMd),
            Text(
              'Chưa tìm thấy thiết bị nào...',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, _) => SizedBox(height: AppSpacing.gapSm),
      itemBuilder: (_, idx) => _DeviceTile(
        device: devices[idx],
        onTap: () => provider.selectDiscovered(devices[idx]),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onTap;
  const _DeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMock = device.source == DeviceDiscoverySource.mock;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.radiusLg),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.gapMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.radiusLg),
          border: Border.all(color: AppColors.strokeSoft),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.gapSm),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                device.deviceType == 'fitness_band'
                    ? Icons.monitor_heart_rounded
                    : Icons.watch_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
            SizedBox(width: AppSpacing.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device.name,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMock) ...[
                        SizedBox(width: AppSpacing.gapXs),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppStateColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MOCK',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppSpacing.gapXs),
                  Text(
                    'MAC: ${device.macAddress} · RSSI ${device.rssi} dBm',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ScanErrorView extends StatelessWidget {
  final String message;
  final BleFailureReason? reason;
  final VoidCallback onRetry;

  const _ScanErrorView({
    required this.message,
    required this.reason,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tip = _hintFor(reason);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.bluetooth_disabled_rounded,
              size: 64, color: AppColors.warning),
          SizedBox(height: AppSpacing.gapMd),
          Text(
            message,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          if (tip != null) ...[
            SizedBox(height: AppSpacing.gapSm),
            Text(
              tip,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: AppSpacing.sectionGapMd),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Quét lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps the typed [BleFailureReason] to user-actionable advice. Keeping
  /// the mapping here means the provider does not need to format strings.
  String? _hintFor(BleFailureReason? reason) {
    switch (reason) {
      case BleFailureReason.adapterOff:
        return 'Hãy bật Bluetooth trong cài đặt nhanh và thử lại.';
      case BleFailureReason.permissionDenied:
        return 'Cấp quyền Bluetooth khi hệ thống hỏi để quét được thiết bị.';
      case BleFailureReason.permissionPermanentlyDenied:
        return 'Mở Cài đặt > Ứng dụng > HealthGuard > Quyền và bật Bluetooth.';
      case BleFailureReason.locationServicesOff:
        return 'Android < 12 yêu cầu bật Vị trí để quét BLE.';
      case BleFailureReason.scanTimeout:
        return 'Đảm bảo đồng hồ đang bật và chưa kết nối với app khác.';
      case BleFailureReason.unsupported:
        return 'Thiết bị này không có sóng BLE — hãy thử trên điện thoại thật.';
      case BleFailureReason.connectFailed:
      case BleFailureReason.unknown:
      case null:
        return null;
    }
  }
}
