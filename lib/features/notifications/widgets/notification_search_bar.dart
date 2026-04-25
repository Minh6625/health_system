import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';

/// Top search bar for the notifications screen — filters by title or message.
///
/// The parent `NotificationsScreen` owns the [TextEditingController] (so the
/// debounce + state lives there); this widget only renders the input.
class NotificationSearchBar extends StatelessWidget {
  const NotificationSearchBar({
    super.key,
    required this.controller,
    required this.hasQuery,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadii.radiusSm),
          border: Border.all(color: AppColors.strokeSoft),
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Tìm theo tiêu đề hoặc nội dung...',
            hintStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: AppColors.textSecondary,
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}
