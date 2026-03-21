import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_connect_provider.dart';

class DeviceConnectErrorCard extends StatelessWidget {
  const DeviceConnectErrorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, size: 64, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Không thể kết nối',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF12304A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            provider.errorMessage ?? 'Đã có lỗi xảy ra trong quá trình nhận diện. Vui lòng thử lại.',
            style: const TextStyle(fontSize: 16, color: Color(0xFF5B7288), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: provider.backToIntro,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF12304A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Thử lại', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
