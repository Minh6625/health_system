import 'package:flutter/material.dart';

class MyCodeHeroCard extends StatelessWidget {
  final String pinCode;
  final String expiryText;
  final VoidCallback onShare;

  const MyCodeHeroCard({
    super.key,
    required this.pinCode,
    required this.expiryText,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mock QR Code Block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: const Icon(
              Icons.qr_code_2,
              size: 180,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 24),
          // PIN
          Text(
            pinCode,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: Color(0xFF2F80ED),
            ),
          ),
          const SizedBox(height: 8),
          // Expiry info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: Color(0xFFF2A93B),
              ),
              const SizedBox(width: 6),
              Text(
                'Có hiệu lực đến $expiryText',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF2A93B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text(
                'Chia sẻ mã',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEF4FF),
                foregroundColor: const Color(0xFF2F80ED),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
