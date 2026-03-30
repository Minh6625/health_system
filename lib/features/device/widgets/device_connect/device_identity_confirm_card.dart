import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_connect_provider.dart';

class DeviceIdentityConfirmCard extends StatelessWidget {
  const DeviceIdentityConfirmCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();
    final device = provider.identifiedDevice;
    final isPairing = provider.state == DeviceConnectState.pairing;

    if (device == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Đã tìm thấy thiết bị',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF12304A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Kiểm tra thông tin bên dưới và xác nhận để hoàn tất kết nối.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF5B7288),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F7FB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.watch_rounded, size: 64, color: Color(0xFF0F766E)),
                ),
                const SizedBox(height: 24),
                Text(
                  device.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF12304A)),
                ),
                const SizedBox(height: 8),
                Text(
                  'MAC: ${device.macAddress}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isPairing ? null : provider.confirmAndPair,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: isPairing
                        ? const SizedBox(
                            height: 24, 
                            width: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text(
                            'Kết nối máy này',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
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
