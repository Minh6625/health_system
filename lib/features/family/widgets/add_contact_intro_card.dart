import 'package:flutter/material.dart';

class AddContactIntroCard extends StatelessWidget {
  const AddContactIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF), // bg.elevated
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Color(0xFF2F80ED),
            ), // brand.primary
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kết nối người thân',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF12304A), // text.primary
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Thêm liên hệ an toàn bằng cách quét mã, chia sẻ mã QR hoặc tìm qua số điện thoại.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5B7288), // text.secondary
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
