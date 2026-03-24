import 'package:flutter/material.dart';

class PermissionSetupBottomSheet extends StatefulWidget {
  final String contactName;
  final Function(List<String> permissions) onConfirm;

  const PermissionSetupBottomSheet({
    super.key,
    required this.contactName,
    required this.onConfirm,
  });

  @override
  State<PermissionSetupBottomSheet> createState() =>
      _PermissionSetupBottomSheetState();
}

class _PermissionSetupBottomSheetState
    extends State<PermissionSetupBottomSheet> {
  bool canViewVitals = false; // Default safe
  bool canReceiveAlerts = true; // Default safe
  bool canViewLocation = true; // Default safe

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn muốn chia sẻ gì với ${widget.contactName}?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lưu ý: Bạn có thể thay đổi các quyền này bất kỳ lúc nào trong cài đặt liên hệ.',
            style: TextStyle(fontSize: 14, color: Color(0xFF5B7288)),
          ),
          const SizedBox(height: 24),
          _buildToggle(
            title: 'Xem chỉ số sức khoẻ',
            description: 'Cho phép người này xem nhịp tim, huyết áp...',
            value: canViewVitals,
            onChanged: (val) => setState(() => canViewVitals = val),
          ),
          const SizedBox(height: 16),
          _buildToggle(
            title: 'Nhận cảnh báo khẩn cấp (SOS)',
            description:
                'Người này sẽ nhận được thông báo khi bạn gặp nguy hiểm.',
            value: canReceiveAlerts,
            onChanged: (val) => setState(() => canReceiveAlerts = val),
          ),
          const SizedBox(height: 16),
          _buildToggle(
            title: 'Xem vị trí hiện tại',
            description: 'Cần thiết trong trường hợp khẩn cấp.',
            value: canViewLocation,
            onChanged: (val) => setState(() => canViewLocation = val),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Cài sau: Keep safe defaults
                    Navigator.pop(context);
                    widget.onConfirm([
                      'can_receive_alerts',
                      'can_view_location',
                    ]);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B7288),
                    side: const BorderSide(color: Color(0xFF5B7288)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cài sau',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final perms = <String>[];
                    if (canViewVitals) perms.add('can_view_vitals');
                    if (canReceiveAlerts) perms.add('can_receive_alerts');
                    if (canViewLocation) perms.add('can_view_location');

                    Navigator.pop(context);
                    widget.onConfirm(perms);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F80ED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Xác nhận',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF12304A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5B7288),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2E9B6F),
          ),
        ],
      ),
    );
  }
}
