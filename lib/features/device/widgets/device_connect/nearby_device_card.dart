import 'package:flutter/material.dart';
import 'package:healthguard/features/device/mock/device_mock_data.dart';

class NearbyDeviceCard extends StatelessWidget {
  final MockBleDevice device;
  final VoidCallback onTap;

  const NearbyDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData = Icons.watch;
    if (device.deviceType == 'fitness_band') {
      iconData = Icons.watch_later_outlined;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: const Color(0xFF0F766E), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Loại: ${device.deviceType == 'smartwatch' ? 'Đồng hồ thông minh' : 'Vòng đeo tay'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
