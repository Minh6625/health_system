import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';

class DeviceHealthHeroCard extends StatelessWidget {
  const DeviceHealthHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final total = provider.devices.length;
    final attention = provider.needsAttentionDevices.length;
    final healthy = total - attention;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E), // brand.primary
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F766E),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thiết bị của bạn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0 
                ? 'Hãy kết nối thiết bị để theo dõi'
                : (healthy == total 
                    ? 'Tất cả thiết bị đang hoạt động tốt' 
                    : '$healthy thiết bị đang hoạt động tốt'),
            style: const TextStyle(
              color: Color(0xFFE6FFFB), // brand.soft
              fontSize: 16,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMetricTile('Tổng', total.toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile('Ổn định', healthy.toString())),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile('Cần chú ý', attention.toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: const TextStyle(
              color: Color(0xFFE6FFFB),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
