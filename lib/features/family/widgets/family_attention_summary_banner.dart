import 'package:flutter/material.dart';

class FamilyAttentionSummaryBanner extends StatelessWidget {
  final int count;

  const FamilyAttentionSummaryBanner({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2A93B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF2A93B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Có $count người đang cần cần bạn chú ý theo dõi.',
              style: const TextStyle(
                color: Color(0xFF12304A),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
