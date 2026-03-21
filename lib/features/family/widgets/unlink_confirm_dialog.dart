import 'package:flutter/material.dart';

class UnlinkConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const UnlinkConfirmDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Hủy liên kết?',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF12304A),
        ),
      ),
      content: const Text(
        'Hành động này sẽ xóa người dùng khỏi danh sách liên hệ của bạn và thu hồi toàn bộ quyền truy cập. Bạn có chắc chắn muốn tiếp tục?',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF5B7288),
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Không, giữ lại',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B7288),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC94A4A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: const Text(
            'Hủy liên kết',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
