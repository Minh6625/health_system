import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';

class SharingContextInfoBanner extends StatelessWidget {
  final LinkedContactModel contact;

  const SharingContextInfoBanner({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    // Extract short name for readability if there is a prefix like 'Bố - '
    String shortName = contact.displayName;
    if (shortName.contains(' - ')) {
      shortName = shortName.split(' - ').first;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryLight,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.brandPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bạn đang chia sẻ thông tin của mình cho $shortName',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
