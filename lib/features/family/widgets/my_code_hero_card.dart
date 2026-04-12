import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyCodeHeroCard extends StatelessWidget {
  final String qrData;
  final String pinCode;
  final VoidCallback onShare;

  const MyCodeHeroCard({
    super.key,
    required this.qrData,
    required this.pinCode,
    required this.onShare,
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
          // PIN
          Text(
            pinCode,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 32),
          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text(
                'Chia sẻ mã',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimaryLight,
                foregroundColor: AppColors.brandPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
