import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/providers/linked_contact_detail_mock_provider.dart';
import 'package:healthguard/features/family/widgets/label_management_card.dart';
import 'package:healthguard/features/family/widgets/linked_contact_hero_card.dart';
import 'package:healthguard/features/family/widgets/permission_toggle_card.dart';
import 'package:healthguard/features/family/widgets/sharing_context_info_banner.dart';
import 'package:healthguard/features/family/widgets/unlink_action_card.dart';
import 'package:healthguard/features/family/widgets/unlink_confirm_dialog.dart';
import 'package:provider/provider.dart';

class LinkedContactDetailScreen extends StatelessWidget {
  final String contactId;

  const LinkedContactDetailScreen({
    super.key,
    required this.contactId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LinkedContactDetailMockProvider()..loadContact(contactId),
      child: const _LinkedContactDetailContent(),
    );
  }
}

class _LinkedContactDetailContent extends StatelessWidget {
  const _LinkedContactDetailContent();

  void _showTagPicker(BuildContext context, LinkedContactDetailMockProvider provider) {
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
            await provider.updateTags(tags);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã cập nhật nhãn liên hệ'),
                  backgroundColor: Color(0xFF2F80ED),
                ),
              );
            }
          },
        );
      },
    );
  }

  void _showLabelEditor(BuildContext context, LinkedContactDetailMockProvider provider) {
    final contact = provider.contact;
    if (contact == null) return;

    final controller = TextEditingController(text: contact.primaryRelationshipLabel);

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
              await provider.updatePrimaryLabel(controller.text);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _handleUnlink(BuildContext context, LinkedContactDetailMockProvider provider) {
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
    final provider = context.watch<LinkedContactDetailMockProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('Quyền chia sẻ', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF12304A))),
        backgroundColor: const Color(0xFFF4F7FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF12304A)),
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, LinkedContactDetailMockProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2F80ED))),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFC94A4A)),
            const SizedBox(height: 16),
            Text(
              'Có lỗi xảy ra',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF12304A)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => provider.loadContact(provider.contact?.id ?? ''),
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        LinkedContactHeroCard(contact: contact),
        SharingContextInfoBanner(contact: contact),
        const SizedBox(height: 24),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: const Text(
            'Quyền hạn của bạn trao',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5B7288)),
          ),
        ),
        const SizedBox(height: 8),
        PermissionToggleCard(
          title: 'Cho phép xem chỉ số sức khoẻ của tôi',
          description: 'Người này sẽ xem được nhịp tim, SpO₂, huyết áp và các chỉ số liên quan của bạn.',
          value: contact.permissions.contains('can_view_vitals'),
          isSaving: provider.isSavingPermission('can_view_vitals'),
          onChanged: (val) => provider.togglePermission('can_view_vitals', val),
        ),
        PermissionToggleCard(
          title: 'Cho phép nhận cảnh báo SOS của tôi',
          description: 'Người này sẽ nhận thông báo khi bạn phát tín hiệu khẩn cấp SOS.',
          value: contact.permissions.contains('can_receive_alerts'),
          isSaving: provider.isSavingPermission('can_receive_alerts'),
          onChanged: (val) => provider.togglePermission('can_receive_alerts', val),
        ),
        PermissionToggleCard(
          title: 'Cho phép xem vị trí của tôi khi SOS',
          description: 'Chỉ chia sẻ vị trí trong tình huống khẩn cấp để hỗ trợ tìm kiếm nhanh hơn.',
          value: contact.permissions.contains('can_view_location'),
          isSaving: provider.isSavingPermission('can_view_location'),
          onChanged: (val) => provider.togglePermission('can_view_location', val),
        ),
        
        const SizedBox(height: 16),
        LabelManagementCard(
          title: 'Nhãn chính hiển thị',
          currentLabel: contact.primaryRelationshipLabel,
          isUpdating: provider.isUpdatingLabel,
          onTapChange: () => _showLabelEditor(context, provider),
        ),
        const SizedBox(height: 8),
        LabelManagementCard(
          title: 'Tags phân nhóm',
          currentLabel: contact.tags.isEmpty ? 'Chưa gắn tag' : contact.tags.map((t) => t.name).join(', '),
          isUpdating: provider.isUpdatingLabel,
          onTapChange: () => _showTagPicker(context, provider),
        ),

        const SizedBox(height: 24),
        UnlinkActionCard(
          isUnlinking: provider.isUnlinking,
          onUnlink: () => _handleUnlink(context, provider),
        ),
      ],
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const Text(
            'Phân nhóm liên hệ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF12304A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chọn một hoặc nhiều nhóm để phân loại người thân này.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF5B7288)),
          ),
          const SizedBox(height: 24),
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
                  color: isSelected ? tag.color : const Color(0xFF5B7288),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? tag.color : Colors.grey.shade300),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
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
                backgroundColor: const Color(0xFF2F80ED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
