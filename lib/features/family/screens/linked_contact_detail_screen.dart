import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/providers/linked_contact_detail_provider.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/features/family/widgets/label_management_card.dart';
import 'package:healthguard/features/family/widgets/linked_contact_hero_card.dart';
import 'package:healthguard/features/family/widgets/permission_toggle_card.dart';
import 'package:healthguard/features/family/widgets/sharing_context_info_banner.dart';
import 'package:healthguard/features/family/widgets/unlink_action_card.dart';
import 'package:healthguard/features/family/widgets/unlink_confirm_dialog.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:provider/provider.dart';

class LinkedContactDetailScreen extends StatelessWidget {
  final String contactId;
  final FamilyRepository? repository;

  const LinkedContactDetailScreen({
    super.key,
    required this.contactId,
    this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          LinkedContactDetailProvider(repository: repository)
            ..loadContact(contactId),
      child: _LinkedContactDetailContent(contactId: contactId),
    );
  }
}

class _LinkedContactDetailContent extends StatelessWidget {
  const _LinkedContactDetailContent({required this.contactId});

  final String contactId;

  void _showTagPicker(
    BuildContext context,
    LinkedContactDetailProvider provider,
  ) {
    final contact = provider.contact;
    if (contact == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TagPickerSheet(
          initialTags: contact.tags,
          onConfirm: (tags) async {
            Navigator.pop(ctx);

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx2) =>
                  const Center(child: CircularProgressIndicator()),
            );

            final success = await provider.updateTags(tags);

            if (context.mounted) {
              Navigator.pop(context); // Close loading dialog
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã cập nhật nhãn liên hệ'),
                    backgroundColor: AppColors.brandPrimary,
                  ),
                );
              }
            }
          },
        );
      },
    );
  }

  void _showLabelEditor(
    BuildContext context,
    LinkedContactDetailProvider provider,
  ) {
    final contact = provider.contact;
    if (contact == null) return;

    final controller = TextEditingController(
      text: contact.primaryRelationshipLabel,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa nhãn chính'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: Bố, Mẹ, Bác sĩ riêng...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx2) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final success = await provider.updatePrimaryLabel(
                controller.text,
              );

              if (context.mounted) {
                Navigator.pop(context); // Close loading dialog
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã cập nhật nhãn chính'),
                      backgroundColor: AppColors.brandPrimary,
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _handleUnlink(
    BuildContext context,
    LinkedContactDetailProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => UnlinkConfirmDialog(
        onConfirm: () async {
          final success = await provider.unlinkContact();
          if (success && context.mounted) {
            Navigator.of(context).pop(); // Quay lại ContactListScreen
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LinkedContactDetailProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(
          'Quyền chia sẻ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LinkedContactDetailProvider provider,
  ) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPrimary),
        ),
      );
    }

    // Only replace the entire body with an error screen when the initial
    // load failed (contact was never populated). Toggle failures are handled
    // separately via SnackBar so the UI remains usable.
    if (provider.error != null && provider.contact == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.critical),
            SizedBox(height: AppSpacing.gapLg),
            Text(
              'Có lỗi xảy ra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.gapSm),
            ElevatedButton(
              onPressed: () => provider.loadContact(contactId),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final contact = provider.contact;
    if (contact == null) return const SizedBox.shrink();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: AppSpacing.sectionGapXl),
      children: [
        LinkedContactHeroCard(contact: contact),
        SharingContextInfoBanner(contact: contact),
        SizedBox(height: AppSpacing.sectionGapXl),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.gapLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quyền hạn của bạn trao',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              if (provider.hasUnsavedChanges)
                Text(
                  'Chưa lưu',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.gapSm),
        PermissionToggleCard(
          title: 'Cho phép xem chỉ số sức khoẻ của tôi',
          description:
              'Người này sẽ xem được nhịp tim, SpO₂, huyết áp và các chỉ số liên quan của bạn.',
          value: provider.draftPermissions.contains('can_view_vitals'),
          onChanged: (val) =>
              provider.updateDraftPermission('can_view_vitals', val),
        ),
        PermissionToggleCard(
          title: 'Cho phép nhận cảnh báo SOS của tôi',
          description:
              'Người này sẽ nhận thông báo khi bạn phát tín hiệu khẩn cấp SOS.',
          value: provider.draftPermissions.contains('can_receive_alerts'),
          onChanged: (val) =>
              provider.updateDraftPermission('can_receive_alerts', val),
        ),
        PermissionToggleCard(
          title: 'Cho phép xem vị trí của tôi khi SOS',
          description:
              'Chỉ chia sẻ vị trí trong tình huống khẩn cấp để hỗ trợ tìm kiếm nhanh hơn.',
          value: provider.draftPermissions.contains('can_view_location'),
          onChanged: (val) =>
              provider.updateDraftPermission('can_view_location', val),
        ),
        PermissionToggleCard(
          title: 'Cho phép xem hồ sơ y tế của tôi',
          description:
              'Người này sẽ xem được nhóm máu, chiều cao/cân nặng, thuốc đang dùng, dị ứng và tiền sử bệnh bạn đã khai báo.',
          value: provider.draftPermissions.contains('can_view_medical_info'),
          onChanged: (val) =>
              provider.updateDraftPermission('can_view_medical_info', val),
        ),
        SizedBox(height: AppSpacing.gapSm),
        _SavePermissionsButton(provider: provider),

        SizedBox(height: AppSpacing.gapLg),
        LabelManagementCard(
          title: 'Nhãn chính hiển thị',
          currentLabel: contact.primaryRelationshipLabel,
          isUpdating: provider.isUpdatingLabel,
          onTapChange: () => _showLabelEditor(context, provider),
        ),
        SizedBox(height: AppSpacing.gapSm),
        LabelManagementCard(
          title: 'Tags phân nhóm',
          currentLabel: contact.tags.isEmpty
              ? 'Chưa gắn tag'
              : contact.tags.map((t) => t.name).join(', '),
          isUpdating: provider.isUpdatingLabel,
          onTapChange: () => _showTagPicker(context, provider),
        ),

        SizedBox(height: AppSpacing.sectionGapXl),
        UnlinkActionCard(
          isUnlinking: provider.isUnlinking,
          onUnlink: () => _handleUnlink(context, provider),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Save Permissions Button
// ---------------------------------------------------------------------------

class _SavePermissionsButton extends StatelessWidget {
  final LinkedContactDetailProvider provider;

  const _SavePermissionsButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasChanges = provider.hasUnsavedChanges;
    final isSaving = provider.isSavingPermissions;
    final saveError = provider.savePermissionsError;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (saveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Lưu thất bại. Vui lòng kiểm tra kết nối và thử lại.',
                style: TextStyle(fontSize: 13, color: AppColors.critical),
                textAlign: TextAlign.center,
              ),
            ),
          ElevatedButton(
            onPressed: (hasChanges && !isSaving)
                ? () async {
                    final ok = await provider.savePermissions();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Đã lưu quyền thành công.'
                                : 'Lưu thất bại. Vui lòng thử lại.',
                          ),
                          backgroundColor:
                              ok ? AppColors.brandPrimary : AppColors.critical,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              disabledBackgroundColor: AppColors.strokeSoft,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    hasChanges ? 'Lưu thay đổi' : 'Đã lưu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: hasChanges ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TagPickerSheet extends StatefulWidget {
  final List<ContactTag> initialTags;
  final Function(List<ContactTag>) onConfirm;

  const _TagPickerSheet({required this.initialTags, required this.onConfirm});

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late Set<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = widget.initialTags.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.sectionGapXl, AppSpacing.sectionGapSm, AppSpacing.sectionGapXl, 32),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: AppSpacing.sectionGapXl),
            decoration: BoxDecoration(
              color: AppColors.strokeSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Phân nhóm liên hệ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.gapSm),
          Text(
            'Chọn một hoặc nhiều nhóm để phân loại người thân này.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          SizedBox(height: AppSpacing.sectionGapXl),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: ContactTagsConfig.defaultTags.map((tag) {
              final isSelected = _selectedTagIds.contains(tag.id);
              return FilterChip(
                label: Text(tag.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTagIds.add(tag.id);
                    } else {
                      _selectedTagIds.remove(tag.id);
                    }
                  });
                },
                selectedColor: tag.color.withValues(alpha: 0.12),
                checkmarkColor: tag.color,
                labelStyle: TextStyle(
                  color: isSelected ? tag.color : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.radiusXl),
                  side: BorderSide(
                    color: isSelected ? tag.color : AppColors.strokeSoft,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32), // intentional larger gap
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final selectedTags = ContactTagsConfig.defaultTags
                    .where((t) => _selectedTagIds.contains(t.id))
                    .toList();
                widget.onConfirm(selectedTags);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.bgSurface,
                padding: EdgeInsets.symmetric(vertical: AppSpacing.gapLg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Lưu thay đổi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
