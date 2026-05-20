import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

/// Honest disclosure surfaced on every screen of the device-connect flow.
///
/// Phase 1 Option A scope: this screen runs a real BLE scan, picks up the
/// device's actual MAC and DIS metadata, and records it against the user
/// account. It does NOT bond at the OS level because Redmi/Xiaomi watches
/// only exchange meaningful data with Mi Fitness — forcing a bond would
/// either fail or leave a dead pairing in the OS settings.
///
/// The banner makes that boundary explicit so the user understands why
/// they still need Mi Fitness for vital-sign sync, and why the simulator
/// is the demo data source until the Xiaomi protobuf path is implemented.
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
              'Quét BLE thật: app sẽ ghi nhận MAC + thông tin chuẩn của '
              'đồng hồ. Để đồng bộ dữ liệu sức khoẻ từ Redmi/Xiaomi, '
              'hoàn tất ghép nối qua Mi Fitness và dùng Simulator để demo '
              'pipeline.',
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
