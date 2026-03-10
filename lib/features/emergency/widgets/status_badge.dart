import 'package:flutter/material.dart';

/// Status badge for SOS events
class StatusBadge extends StatelessWidget {
  final String status; // 'active' | 'resolved'

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isActive ? 'Đang hoạt động' : 'Đã xử lý',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
