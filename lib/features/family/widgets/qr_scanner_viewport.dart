import 'package:flutter/material.dart';

class QRScannerViewport extends StatelessWidget {
  final VoidCallback onSimulateScanSuccess;
  final VoidCallback onSimulateScanError;

  const QRScannerViewport({
    super.key,
    required this.onSimulateScanSuccess,
    required this.onSimulateScanError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Dark grey for camera feel
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Focus Frame
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2F80ED), width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          // Scanning Line (Fake animation effect)
          Positioned(
            top: 200, // Arbitrary position for mockup
            child: Container(
              width: 240,
              height: 2,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2F80ED).withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
                color: const Color(0xFF2F80ED),
              ),
            ),
          ),
          // Tooltip/Helper Text
          const Positioned(
            bottom: 32,
            child: Text(
              'Đưa mã QR vào giữa khung để quét',
              style: TextStyle(
                color: Colors.white, 
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Flashlight Toggle (Mock)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.flash_off, color: Colors.white, size: 24),
                onPressed: () {},
              ),
            ),
          ),
          // Debug Actions for Simulation
          Positioned(
            bottom: 80,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: onSimulateScanSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Sim: OK'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onSimulateScanError,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Sim: Error'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
