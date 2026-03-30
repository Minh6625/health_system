import 'package:flutter/material.dart';

class DeviceOnboardingEmptyState extends StatelessWidget {
  const DeviceOnboardingEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Color(0xFFE6FFFB), // brand.soft
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.watch_rounded, size: 64, color: Color(0xFF0F766E)), // brand.primary
          ),
          const SizedBox(height: 24),
          const Text(
            'Bắt đầu theo dõi sức khoẻ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF12304A), // text.primary
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Kết nối đồng hồ thông minh hoặc thiết bị y tế\nđể xem các chỉ số liên tục và thông minh.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF5B7288), // text.secondary
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
