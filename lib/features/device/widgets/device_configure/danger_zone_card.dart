import 'package:flutter/material.dart';

class DangerZoneCard extends StatelessWidget {
  final VoidCallback onUnpair;
  final bool isUnpairing;

  const DangerZoneCard({
    super.key,
    required this.onUnpair,
    this.isUnpairing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Vùng nguy hiểm',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDC2626), // danger color
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2), // very light red
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)), // light red border
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ngắt kết nối thiết bị này khỏi tài khoản của bạn. Xóa bỏ toàn bộ cấu hình liên kết.',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: isUnpairing ? null : onUnpair,
                icon: isUnpairing ? const SizedBox.shrink() : const Icon(Icons.link_off_rounded),
                label: isUnpairing 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Ngắt kết nối thiết bị', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
