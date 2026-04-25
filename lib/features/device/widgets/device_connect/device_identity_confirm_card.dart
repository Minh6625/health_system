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
                // Phase 5c-A: the pair button is locked because confirmAndPair
                // would otherwise call POST /devices/scan/pair with the
                // hard-coded mock MAC. We keep the visual affordance so the
                // demo flow is still navigable, but onPressed is null until a
                // real BLE/manual-code endpoint is wired in.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
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
                    child: const Text(
                      'Kết nối máy này (đang phát triển)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.gapSm),
                Text(
                  'Để bảo vệ dữ liệu, hệ thống không lưu thiết bị mẫu vào '
                  'tài khoản. Tính năng kết nối thật sẽ mở khi BLE thực '
                  'sẵn sàng.',
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
