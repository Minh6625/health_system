import 'package:flutter/material.dart';

class FamilyOnboardingEmptyState extends StatelessWidget {
  final VoidCallback onAddContact;

  const FamilyOnboardingEmptyState({super.key, required this.onAddContact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: Color(0xFF2F80ED),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Chưa có liên kết người thân',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hãy thêm người thân vào danh sách theo dõi để giúp bạn chăm sóc sức khoẻ của họ tốt hơn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF5B7288),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onAddContact,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F80ED),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Liên kết người thân',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
