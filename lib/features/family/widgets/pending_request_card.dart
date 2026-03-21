import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/linked_contact_model.dart';
import '../providers/shared_family_mock_provider.dart';
import 'permission_setup_bottom_sheet.dart';

class PendingRequestCard extends StatelessWidget {
  final LinkedContactModel request;

  const PendingRequestCard({super.key, required this.request});

  void _onAccept(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PermissionSetupBottomSheet(
        contactName: request.displayName,
        onConfirm: (permissions) async {
          final provider = context.read<SharedFamilyMockProvider>();
          await provider.acceptRequest(request.id, permissions);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã chấp nhận liên kết với ${request.displayName}')),
            );
          }
        },
      ),
    );
  }

  void _onReject(BuildContext context) async {
    final provider = context.read<SharedFamilyMockProvider>();
    await provider.rejectRequest(request.id);
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã từ chối liên kết với ${request.displayName}')),
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9), // bg.pending
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2A93B).withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF2A93B).withValues(alpha: 0.2),
                child: Text(
                  request.displayName.isNotEmpty ? request.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF2A93B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF12304A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Muốn kết nối với bạn',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5B7288),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _onReject(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B7288),
                    side: const BorderSide(color: Color(0xFF5B7288)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 48), // Accessbility standard
                  ),
                  child: const Text('Hủy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _onAccept(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F80ED), // brand.primary
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Xác nhận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
