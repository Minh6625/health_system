import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';

class LinkedContactHeroCard extends StatelessWidget {
  final LinkedContactModel contact;

  const LinkedContactHeroCard({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(color: AppColors.bgPrimary),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.strokeSoft,
            backgroundImage: contact.avatarUrl.isNotEmpty
                ? NetworkImage(contact.avatarUrl)
                : null,
            child: contact.avatarUrl.isEmpty
                ? Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            contact.displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandPrimaryLight,
              borderRadius: BorderRadius.circular(AppRadii.radiusLg),
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.label_outline,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Nhãn: ${contact.role.label}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
