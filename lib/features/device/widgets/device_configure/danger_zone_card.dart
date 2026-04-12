import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DangerZoneCard extends StatelessWidget {
  final VoidCallback onUnpair;
  final bool isUnpairing;

  const DangerZoneCard({
    super.key,
    required this.onUnpair,
    this.isUnpairing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: AppSpacing.gapMd),
          child: Text(
            'Vùng nguy hiểm',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.critical,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStateColors.criticalBg,
            borderRadius: BorderRadius.circular(AppRadii.radiusLg),
            border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ngắt kết nối thiết bị này khỏi tài khoản của bạn. Xóa bỏ toàn bộ cấu hình liên kết.',
                style: AppTextStyles.caption.copyWith(color: AppColors.critical),
              ),
              SizedBox(height: AppSpacing.sectionGapMd),
              ElevatedButton.icon(
                onPressed: isUnpairing ? null : onUnpair,
                icon: isUnpairing ? const SizedBox.shrink() : const Icon(Icons.link_off_rounded),
                label: isUnpairing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Ngắt kết nối thiết bị', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.radiusMd)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
