import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

class LinkedContactsHeroCard extends StatelessWidget {
  final int totalContacts;
  final int pendingCount;
  final VoidCallback onAddPressed;

  const LinkedContactsHeroCard({
    super.key,
    required this.totalContacts,
    required this.pendingCount,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryLight, // bg.elevated
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group, color: Colors.blue.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Liên kết của bạn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary, // text.primary
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalContacts liên hệ${pendingCount > 0 ? ' • $pendingCount yêu cầu chờ xử lý' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary, // text.secondary
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary, // brand.primary
                foregroundColor: AppColors.bgSurface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Thêm liên hệ mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
