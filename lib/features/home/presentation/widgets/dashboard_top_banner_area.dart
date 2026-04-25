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
    Widget? banner;
    if (vm.hasError) {
      banner = InlineErrorBlock(
        message: vm.errorMessage ?? 'Không thể tải dữ liệu sức khoẻ lúc này.',
        onRetry: () {
          // Error handling usually invokes onRefresh or specific retry event
          vm.onRefresh();
        },
      );
    } else if (vm.isOffline) {
      banner = InlineStatusBanner.offline(
        message: 'Đang hiển thị dữ liệu đã lưu.',
      );
    } else if (vm.hasWarningBanner) {
      banner = InlineStatusBanner.warning(
        message: 'Một số chỉ số cần chú ý hôm nay.',
      );
    }

    if (banner == null) return const SizedBox.shrink();

    // Apply top gap only when a banner is shown so it does not stick to the
    // ConnectionStatusStrip above. Bottom spacing is handled by the screen
    // (sectionGapXl between Vùng A and Vùng B).
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.gapSm),
      child: banner,
    );
  }
}
