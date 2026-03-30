import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class MedicalDisclaimerCard extends StatelessWidget {
  const MedicalDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: Text(
              'Các đánh giá này được thiết lập bởi AI và chỉ mang tính chất tham khảo. KHÔNG dùng để thay thế chẩn đoán y khoa chuyên nghiệp.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
