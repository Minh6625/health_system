import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

class UnlinkActionCard extends StatelessWidget {
  final VoidCallback onUnlink;
  final bool isUnlinking;

  const UnlinkActionCard({
    super.key,
    required this.onUnlink,
    this.isUnlinking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStateColors.criticalBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusLg),
        border: Border.all(
          color: AppColors.critical.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Khu vực nhạy cảm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.critical,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: isUnlinking ? null : onUnlink,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.critical),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                ),
                foregroundColor: AppColors.critical,
              ),
              child: isUnlinking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.critical,
                        ),
                      ),
                    )
                  : const Text(
                      'Hủy liên kết',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
