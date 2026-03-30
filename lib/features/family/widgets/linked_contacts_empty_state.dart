import 'package:flutter/material.dart';

class LinkedContactsEmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const LinkedContactsEmptyState({super.key, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có liên kết nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dùng tính năng chia sẻ kết nối để theo dõi sức khoẻ người thân hoặc chia sẻ cho bác sĩ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF5B7288)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F80ED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              minimumSize: const Size(200, 52),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text(
              'Thêm liên hệ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
