import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';

class ScannedUserConfirmSheet extends StatefulWidget {
  /// Callback trả về danh sách tags đã chọn + email
  final Function(List<ContactTag> tags, String email)? onConfirm;
  final VoidCallback onCancel;

  const ScannedUserConfirmSheet({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<ScannedUserConfirmSheet> createState() => _ScannedUserConfirmSheetState();
}

class _ScannedUserConfirmSheetState extends State<ScannedUserConfirmSheet> {
  final Set<String> _selectedTagIds = {'family'}; // default: Gia đình

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          // User info (mock)
          const CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFFEEF4FF),
            child: Text('A', style: TextStyle(fontSize: 28, color: Color(0xFF2F80ED), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Anh Tuấn',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF12304A)),
          ),
          const SizedBox(height: 4),
          Text('anhtuan@example.com', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          // Tags – multi-select, từ ContactTagsConfig
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gắn nhãn liên hệ (có thể chọn nhiều):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF12304A)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ContactTagsConfig.defaultTags.map((tag) {
              final isSelected = _selectedTagIds.contains(tag.id);
              return FilterChip(
                avatar: isSelected
                    ? Icon(Icons.check, size: 14, color: tag.color)
                    : null,
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
                backgroundColor: Colors.white,
                checkmarkColor: tag.color,
                showCheckmark: false,
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
          const SizedBox(height: 8),
          // Hint khi chưa chọn tag
          if (_selectedTagIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Liên hệ sẽ được xếp vào mục "Chưa gắn tag"',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B7288),
                    side: const BorderSide(color: Color(0xFF5B7288)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Quét lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Map selectedTagIds → danh sách ContactTag object
                    final selectedTags = ContactTagsConfig.defaultTags
                        .where((t) => _selectedTagIds.contains(t.id))
                        .toList();
                    widget.onConfirm?.call(selectedTags, 'anhtuan@example.com');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F80ED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Gửi lời mời', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
