import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class FamilyOnboardingEmptyState extends StatelessWidget {
  final VoidCallback onAddContact;

  const FamilyOnboardingEmptyState({super.key, required this.onAddContact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.brandPrimaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Chưa có liên kết người thân',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.gapLg),
          const Text(
            'Hãy thêm người thân vào danh sách theo dõi để giúp bạn chăm sóc sức khoẻ của họ tốt hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onAddContact,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.radiusLg),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Liên kết người thân',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.bgSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
