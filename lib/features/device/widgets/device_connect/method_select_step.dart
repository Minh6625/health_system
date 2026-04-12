import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../providers/device_connect_provider.dart';

class MethodSelectStep extends StatelessWidget {
  const MethodSelectStep({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DeviceConnectProvider>();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionGapLg,
        vertical: AppSpacing.sectionGapXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kết nối đồng hồ của bạn',
            style: AppTextStyles.sectionTitle.copyWith(fontSize: 24),
          ),
          SizedBox(height: AppSpacing.gapMd),
          Text(
            'Chỉ cần quét mã QR trên màn hình đồng hồ hoặc nhập mã thiết bị để bắt đầu theo dõi sức khoẻ.',
            style: AppTextStyles.body.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 48),
          _buildMethodCard(
            title: 'Quét QR thiết bị',
            subtitle: 'Nhanh hơn, ít phải nhập tay',
            icon: Icons.qr_code_scanner_rounded,
            onTap: provider.openQrScanner,
          ),
          SizedBox(height: AppSpacing.sectionGapMd),
          _buildMethodCard(
            title: 'Nhập mã thiết bị',
            subtitle: 'Dùng khi camera lỗi hoặc QR mờ',
            icon: Icons.keyboard_alt_outlined,
            onTap: provider.openManualMode,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.radiusXl),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.sectionGapLg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.radiusXl),
          border: Border.all(color: AppColors.strokeSoft),
          boxShadow: AppShadows.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.gapMd),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: AppColors.brandPrimary),
            ),
            SizedBox(width: AppSpacing.sectionGapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: AppSpacing.gapXs),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
