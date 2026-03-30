import 'package:flutter/material.dart';

class FamilyHealthHeroCard extends StatelessWidget {
  final int totalCount;
  final int stableCount;
  final int attentionCount;

  const FamilyHealthHeroCard({
    super.key,
    required this.totalCount,
    required this.stableCount,
    required this.attentionCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng tiêu đề gộp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.family_restroom,
                  color: Color(0xFF2F80ED),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gia đình của bạn · $totalCount người đang theo dõi',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF12304A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stat chips
          Row(
            children: [
              _buildStatChip(
                label: 'Tổng',
                value: totalCount.toString(),
                color: const Color(0xFF2F80ED),
                bgColor: Colors.white,
              ),
              const SizedBox(width: 6),
              _buildStatChip(
                label: 'Ổn định',
                value: stableCount.toString(),
                color: const Color(0xFF2E9B6F),
                bgColor: const Color(0xFFE8F5EE),
              ),
              const SizedBox(width: 6),
              _buildStatChip(
                label: 'Cần chú ý',
                value: attentionCount.toString(),
                color: const Color(0xFFF2A93B),
                bgColor: const Color(0xFFFDF4E5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
