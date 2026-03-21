import 'package:flutter/material.dart';

class FamilySOSPriorityBanner extends StatelessWidget {
  final int sosCount;
  final VoidCallback onTap;

  const FamilySOSPriorityBanner({
    super.key,
    required this.sosCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sosCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFD95C5C),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD95C5C).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Có $sosCount người đang cần trợ giúp ngay!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFD95C5C),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(60, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xem ngay'),
          ),
        ],
      ),
    );
  }
}
