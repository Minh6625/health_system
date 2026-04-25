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
/// returns the same mock device. Confirming then writes that fake device
/// into the real backend via `POST /devices/scan/pair`.
///
/// Hiding that fact from the user produced a classic "lying UI": people
/// thought they had paired their watch when they had really bound a
/// placeholder. This banner makes the situation explicit so testers and
/// reviewers know what they are seeing.
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
              'Quét QR/BLE đang ở chế độ demo: hệ thống sẽ tự gắn một '
              'thiết bị mẫu để minh hoạ quy trình. Tính năng quét thật sẽ '
              'có ở bản tiếp theo.',
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
