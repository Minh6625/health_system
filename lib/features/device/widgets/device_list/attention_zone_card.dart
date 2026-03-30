import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';

class AttentionZoneCard extends StatelessWidget {
  const AttentionZoneCard({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<DeviceProvider>().needsAttentionDevices.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // orange.50
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFED7AA)), // orange.200
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDD5), // orange.100
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE67E22), size: 28), // critical
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cần kiểm tra ngay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706), // critical
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Có $count thiết bị đang pin yếu hoặc mất kết nối lâu.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFD97706),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    // Optional quick filter interaction
                  },
                  child: const Text(
                    'Xem thiết bị cần chú ý →',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
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
