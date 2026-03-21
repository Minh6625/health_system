import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_connect_provider.dart';

class MethodSelectStep extends StatelessWidget {
  const MethodSelectStep({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DeviceConnectProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kết nối đồng hồ của bạn',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF12304A), // text.primary
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chỉ cần quét mã QR trên màn hình đồng hồ hoặc nhập mã thiết bị để bắt đầu theo dõi sức khoẻ.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF5B7288), // text.secondary
            ),
          ),
          const SizedBox(height: 48),
          
          _buildMethodCard(
            title: 'Quét QR thiết bị',
            subtitle: 'Nhanh hơn, ít phải nhập tay',
            icon: Icons.qr_code_scanner_rounded,
            onTap: provider.openQrScanner,
          ),
          const SizedBox(height: 16),
          _buildMethodCard(
            title: 'Nhập mã thiết bị',
            subtitle: 'Dùng khi camera lỗi hoặc QR mờ',
            icon: Icons.keyboard_alt_outlined,
            onTap: provider.openManualMode,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE6FFFB), // brand.soft
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: const Color(0xFF0F766E)), // brand.primary
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF12304A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5B7288),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
