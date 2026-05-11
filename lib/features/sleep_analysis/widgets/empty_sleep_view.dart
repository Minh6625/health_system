import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Hiển thị khi user chưa có dữ liệu giấc ngủ (new account / không đeo đồng hồ).
class EmptySleepView extends StatelessWidget {
  const EmptySleepView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF0F2340),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0x4448D6FF),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.bedtime_outlined,
                size: 52,
                color: Color(0xFF48A9D6),
              ),
            ),

            const SizedBox(height: AppSpacing.sectionGapXl),

            const Text(
              'Chưa có dữ liệu giấc ngủ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.gapMd),

            const Text(
              'Hãy đeo đồng hồ khi ngủ để\nứng dụng có thể theo dõi\nvà phân tích giấc ngủ của bạn.',
              style: TextStyle(
                color: Color(0xFF6F8AAE),
                fontSize: 16,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Instruction steps
            _Instruction(
              icon: Icons.watch_rounded,
              text: 'Đeo đồng hồ trước khi đi ngủ',
            ),
            const SizedBox(height: 10),
            _Instruction(
              icon: Icons.bluetooth_rounded,
              text: 'Giữ Bluetooth luôn bật',
            ),
            const SizedBox(height: 10),
            _Instruction(
              icon: Icons.battery_charging_full_rounded,
              text: 'Đảm bảo pin đồng hồ đủ (>20%)',
            ),
          ],
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Instruction({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF48A9D6)),
        const SizedBox(width: AppSpacing.gapSm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF90A6C3),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
