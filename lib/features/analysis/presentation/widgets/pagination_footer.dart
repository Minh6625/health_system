import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';

class PaginationFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;

  const PaginationFooter({
    super.key,
    required this.isLoadingMore,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.gapLg),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapLg),
        child: Center(
          child: Text(
            'Bạn đã xem hết dữ liệu',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: AppSpacing.gapLg);
  }
}
