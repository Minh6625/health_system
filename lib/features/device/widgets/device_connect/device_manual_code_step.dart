import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../providers/device_connect_provider.dart';
import 'device_connect_demo_banner.dart';

class DeviceManualCodeStep extends StatefulWidget {
  const DeviceManualCodeStep({super.key});

  @override
  State<DeviceManualCodeStep> createState() => _DeviceManualCodeStepState();
}

class _DeviceManualCodeStepState extends State<DeviceManualCodeStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();
    final isVerifying = provider.state == DeviceConnectState.verifying;

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
            'Nhập MAC đồng hồ',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 24),
          ),
          SizedBox(height: AppSpacing.gapMd),
          Text(
            'Dùng khi BLE không thấy đồng hồ (đã pair với Mi Fitness). '
            'Mở Cài đặt Android > Bluetooth > thiết bị đã ghép, copy địa '
            'chỉ MAC dạng AA:BB:CC:DD:EE:FF.',
            style: AppTextStyles.body.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _controller,
            enabled: !isVerifying,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace'),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'AA:BB:CC:DD:EE:FF',
              hintStyle: TextStyle(color: AppColors.strokeSoft, letterSpacing: 0, fontFamily: 'monospace'),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                borderSide: BorderSide(color: AppColors.strokeSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                borderSide: BorderSide(color: AppColors.strokeSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
          if (provider.errorMessage != null) ...[
            SizedBox(height: AppSpacing.sectionGapMd),
            Container(
              padding: EdgeInsets.all(AppSpacing.gapMd),
              decoration: BoxDecoration(
                color: AppStateColors.criticalBg,
                borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.critical, size: 20),
                  SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.critical),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isVerifying ? null : () {
              provider.verifyCode(_controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusLg),
              ),
              elevation: 0,
            ),
            child: isVerifying
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Kiểm tra mã',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
