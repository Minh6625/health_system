import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import '../models/contact_tag.dart';
import '../models/linked_contact_model.dart';
import '../providers/family_relationship_provider.dart';
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
          final provider = context.read<FamilyRelationshipProvider>();
          final tags = request.tags.isNotEmpty
              ? request.tags
              : <ContactTag>[ContactTagsConfig.defaultTags.first];
          await provider.acceptRequest(
            request: request,
            permissions: permissions,
            tags: tags,
            primaryLabel: request.primaryRelationshipLabel,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Đã chấp nhận liên kết với ${request.displayName}',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _onReject(BuildContext context) async {
    final provider = context.read<FamilyRelationshipProvider>();
    await provider.rejectRequest(request);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request.isIncomingRequest
                ? 'Đã từ chối liên kết với ${request.displayName}'
                : 'Đã hủy yêu cầu gửi đến ${request.displayName}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E9), // bg.pending
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                child: Text(
                  request.displayName.isNotEmpty
                      ? request.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.isIncomingRequest
                          ? 'Muốn kết nối với bạn'
                          : 'Đang chờ xác nhận...',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
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
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textSecondary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                    ),
                    minimumSize: const Size(0, 48), // Accessbility standard
                  ),
                  child: Text(
                    request.isIncomingRequest ? 'Từ chối' : 'Hủy yêu cầu',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (request.isIncomingRequest) const SizedBox(width: 12),
              if (request.isIncomingRequest)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _onAccept(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary, // brand.primary
                      foregroundColor: AppColors.bgSurface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                      ),
                      elevation: 0,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text(
                      'Xác nhận',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
