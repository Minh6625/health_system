import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

/// Honest disclosure surfaced on every screen of the device-connect flow.
///
/// `DeviceConnectProvider` does **not** drive a real BLE/QR scanner today:
/// `openQrScanner()` waits 2.5s and picks the first entry of
/// `MockBleDiscovery.nearbyDevices` (`VSmart Watch A1` with the hard-coded
/// MAC `AA:BB:CC:11:22:33`); `verifyCode()` ignores the user-typed code and
/// returns the same mock device.
///
/// In Phase 5b this banner only warned the user; we still wrote the fake
/// device to the real backend via `POST /devices/scan/pair` if they tapped
/// confirm. Phase 5c-A locks the final confirm action so we no longer
/// pollute production data — `DeviceIdentityConfirmCard` keeps the button
/// disabled until the real BLE/manual code endpoints land. The banner copy
/// reflects that lock so what the UI says matches what the code does.
class DeviceConnectDemoBanner extends StatelessWidget {
  const DeviceConnectDemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gapMd,
        vertical: AppSpacing.gapSm,
      ),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppColors.warning,
          ),
          SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: Text(
              'Quét QR/BLE đang ở chế độ demo: bạn có thể xem trước các '
              'bước, nhưng nút "Kết nối máy này" tạm khoá để không lưu '
              'thiết bị mẫu vào tài khoản. Tính năng quét thật sẽ có ở '
              'bản tiếp theo.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
