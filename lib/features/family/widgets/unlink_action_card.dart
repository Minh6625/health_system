import 'package:flutter/material.dart';

class UnlinkActionCard extends StatelessWidget {
  final VoidCallback onUnlink;
  final bool isUnlinking;

  const UnlinkActionCard({
    super.key,
    required this.onUnlink,
    this.isUnlinking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEEEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC94A4A).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Khu vực nhạy cảm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC94A4A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: isUnlinking ? null : onUnlink,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC94A4A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: const Color(0xFFC94A4A),
              ),
              child: isUnlinking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC94A4A)),
                      ),
                    )
                  : const Text(
                      'Hủy liên kết',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
