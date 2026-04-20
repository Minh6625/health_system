import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

class NoDataTonightView extends StatelessWidget {
  const NoDataTonightView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF131A2F),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2C4367).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.bedtime_outlined,
                color: Color(0xFF90A6C3),
                size: 64,
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGapXl),
            const Text(
              'Dữ liệu đêm nay chưa sẵn sàng',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.gapMd),
            const Text(
              'Các chỉ số chi tiết về giấc ngủ sẽ được tổng hợp và hiển thị sau 6:00 sáng mai. Chúc bạn ngủ ngon!',
              style: TextStyle(
                color: Color(0xFF90A6C3),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Placeholder for illustration or additional prompt
          ],
        ),
      ),
    );
  }
}
