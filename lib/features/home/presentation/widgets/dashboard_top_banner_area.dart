import 'package:flutter/material.dart';
import '../../../../shared/presentation/feedback/inline_error_block.dart';
import '../../../../shared/presentation/feedback/inline_status_banner.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../models/home_dashboard_view_model.dart';

class DashboardTopBannerArea extends StatelessWidget {
  final HomeDashboardViewModel vm;

  const DashboardTopBannerArea({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.hasError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sectionGapMd),
        child: InlineErrorBlock(
          message: 'Không thể tải dữ liệu sức khoẻ lúc này.',
          onRetry: () {
            // Error handling usually invokes onRefresh or specific retry event
            vm.onRefresh();
          },
        ),
      );
    }

    if (vm.isOffline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sectionGapMd),
        child: InlineStatusBanner.offline(
          message: 'Đang hiển thị dữ liệu đã lưu.',
        ),
      );
    }

    if (vm.hasWarningBanner) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sectionGapMd),
        child: InlineStatusBanner.warning(
          message: 'Một số chỉ số cần chú ý hôm nay.',
        ),
      );
    }

    // Return empty if no banners are needed
    return const SizedBox.shrink();
  }
}
