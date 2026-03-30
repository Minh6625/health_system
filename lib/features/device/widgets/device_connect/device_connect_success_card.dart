import 'package:flutter/material.dart';

class DeviceConnectSuccessCard extends StatelessWidget {
  const DeviceConnectSuccessCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5), // success ultra light
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 80, color: Color(0xFF0F9D7A)), // success color
          ),
          const SizedBox(height: 32),
          const Text(
            'Kết nối thành công!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF12304A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Đồng hồ của bạn đã được thêm vào hệ thống và sẵn sàng theo dõi.',
            style: TextStyle(fontSize: 16, color: Color(0xFF5B7288), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          const CircularProgressIndicator.adaptive(), // Wait for auto-pop
        ],
      ),
    );
  }
}
