import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';

class LockedProfileCard extends StatelessWidget {
  final FamilyProfileSnapshot profile;
  final VoidCallback onManageRoles;

  const LockedProfileCard({
    super.key,
    required this.profile,
    required this.onManageRoles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B7288),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${profile.relation} — ${profile.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF12304A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF5B7288),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bạn chưa được cấp quyền xem dữ liệu sức khoẻ.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF5B7288)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onManageRoles,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2F80ED),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: const Text('Quản lý quyền'),
            ),
          ),
        ],
      ),
    );
  }
}
