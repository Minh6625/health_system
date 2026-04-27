import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';

/// Footer pagination row: `[<- Trước]   Trang X/Y   [Sau ->]`.
///
/// Hidden when there is only a single page.
class NotificationPaginationControls extends StatelessWidget {
  const NotificationPaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Trước'),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Trang $currentPage/$totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Sau'),
          ),
        ],
      ),
    );
  }
}
