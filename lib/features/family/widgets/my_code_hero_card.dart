import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyCodeHeroCard extends StatelessWidget {
  final String qrData;

  const MyCodeHeroCard({
    super.key,
    required this.qrData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Account QR block for sharing/add-contact flow
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadii.radiusLg),
              border: Border.all(color: AppColors.strokeSoft, width: 2),
            ),
            child: QrImageView(
              data: qrData,
              size: 220,
              backgroundColor: AppColors.bgSurface,
              errorStateBuilder: (context, error) {
                return const SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(
                    child: Icon(
                      Icons.qr_code_2,
                      size: 120,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Honest sharing guidance — replaces a hard-coded fake PIN and a
          // mock share button. The backend has no PIN-based connection and the
          // app cannot share an image without an extra dependency, so we tell
          // people exactly what works today.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Người thân quét mã này trực tiếp, hoặc chụp màn hình rồi gửi qua tin nhắn để họ dùng nút "Tải ảnh lên" ở tab quét.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
