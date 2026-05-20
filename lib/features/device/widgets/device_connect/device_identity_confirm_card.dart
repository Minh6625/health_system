import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../providers/device_connect_provider.dart';
import 'device_connect_demo_banner.dart';

class DeviceIdentityConfirmCard extends StatelessWidget {
  const DeviceIdentityConfirmCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();
    final device = provider.identifiedDevice;

    if (device == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionGapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DeviceConnectDemoBanner(),
          SizedBox(height: AppSpacing.sectionGapMd),
          Text(
            'Đã tìm thấy thiết bị',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.gapMd),
          Text(
            'Kiểm tra thông tin bên dưới và xác nhận để hoàn tất kết nối.',
            style: AppTextStyles.body.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: EdgeInsets.all(AppSpacing.sectionGapXl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
              border: Border.all(color: AppColors.strokeSoft),
              boxShadow: AppShadows.elevatedShadow,
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSpacing.sectionGapLg),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.watch_rounded, size: 64, color: AppColors.brandPrimary),
                ),
                SizedBox(height: AppSpacing.sectionGapXl),
                Text(
                  device.name,
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
                ),
                SizedBox(height: AppSpacing.gapSm),
                Text(
                  'MAC: ${device.macAddress}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 40),
                // Phase 1 (Option A — Discovery + Identify only):
                // Redmi/Xiaomi watches require Mi Fitness to complete the
                // proprietary auth handshake. We therefore record the MAC
                // + best-effort GATT metadata (DIS/Battery) without
                // forcing an OS bond. Data sync is delegated to the
                // simulator pipeline until the Xiaomi protobuf path is
                // implemented in a future phase.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.isPairing
                        ? null
                        : provider.confirmAndPair,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.strokeSoft,
                      disabledForegroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      provider.isPairing
                          ? 'Đang ghi nhận...'
                          : 'Ghi nhận thiết bị này',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.gapSm),
                Text(
                  'Ghi nhận MAC vào tài khoản để hệ thống nhận diện đồng hồ. '
                  'Để đồng bộ dữ liệu sức khoẻ (nhịp tim, bước chân...), '
                  'hãy hoàn tất ghép nối qua app Mi Fitness của Xiaomi.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
