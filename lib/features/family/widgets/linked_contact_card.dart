import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/family/providers/shared_family_mock_provider.dart';
import 'package:healthguard/core/routes/app_router.dart';
import '../models/linked_contact_model.dart';

class LinkedContactCard extends StatelessWidget {
  final LinkedContactModel contact;

  const LinkedContactCard({super.key, required this.contact});

  String _buildPermissionsText() {
    if (contact.permissions.isEmpty) return 'Chỉ xem thông tin cơ bản';

    final pItems = <String>[];
    if (contact.permissions.contains('can_receive_alerts')) {
      pItems.add('Nhận cảnh báo (SOS)');
    }
    if (contact.permissions.contains('can_view_vitals')) {
      pItems.add('Xem chỉ số sức khoẻ');
    }
    if (contact.permissions.contains('can_view_location')) {
      pItems.add('Xem vị trí');
    }

    return pItems.join(' • ');
  }

  void _onTap(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      AppRouter.linkedContactDetail,
      arguments: {'contactId': contact.id},
    );

    if (context.mounted) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<SharedFamilyMockProvider>().loadInitialData(
          auth.currentUser!.userId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFEEF4FF),
                  child: Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F80ED),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF12304A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (contact.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Wrap(
                            spacing: 4,
                            children: contact.tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tag.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      tag.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tag.color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      Text(
                        _buildPermissionsText(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B7288),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
