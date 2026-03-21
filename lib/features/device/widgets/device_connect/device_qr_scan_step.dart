import 'package:flutter/material.dart';

class DeviceQrScanStep extends StatelessWidget {
  const DeviceQrScanStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quét mã QR',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF12304A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Hướng camera vào mã QR trên màn hình đồng hồ đang bật.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF5B7288),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF0F766E), width: 3), // brand.primary
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, size: 80, color: Colors.black26),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 120),
                      const CircularProgressIndicator(color: Color(0xFF0F766E)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Đang tìm mã...',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
