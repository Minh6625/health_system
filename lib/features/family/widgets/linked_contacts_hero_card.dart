import 'package:flutter/material.dart';

class LinkedContactsHeroCard extends StatelessWidget {
  final int totalContacts;
  final int pendingCount;
  final VoidCallback onAddPressed;

  const LinkedContactsHeroCard({
    super.key,
    required this.totalContacts,
    required this.pendingCount,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF), // bg.elevated
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.group, color: Colors.blue.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Liên kết của bạn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF12304A), // text.primary
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalContacts liên hệ${pendingCount > 0 ? ' • $pendingCount yêu cầu chờ xử lý' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B7288), // text.secondary
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F80ED), // brand.primary
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Thêm liên hệ mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
