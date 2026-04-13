import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

/// Size of the focus frame overlay (square).
const double _kFrameSize = 240;

/// Duration for one full scan-line cycle (top → bottom).
const Duration _kScanLineDuration = Duration(milliseconds: 2500);

class QRScannerViewport extends StatefulWidget {
  final void Function(String rawValue) onBarcodeDetected;
  final VoidCallback onScanError;

  const QRScannerViewport({
    super.key,
    required this.onBarcodeDetected,
    required this.onScanError,
  });

  @override
  QRScannerViewportState createState() => QRScannerViewportState();
}

class QRScannerViewportState extends State<QRScannerViewport>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;
  bool _hasDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );

    _scanLineController = AnimationController(
      vsync: this,
      duration: _kScanLineDuration,
    );

    _scanLineAnimation = CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    );

    _scanLineController.repeat();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Reset the detection guard so the scanner can detect a new barcode.
  /// Call this after the result sheet is dismissed.
  void resetDetection() {
    _hasDetected = false;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _hasDetected = true;
        widget.onBarcodeDetected(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Live camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Container(
                color: const Color(0xFF1A1A1A),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không thể mở camera.\nVui lòng kiểm tra quyền truy cập.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Focus Frame overlay
          Container(
            width: _kFrameSize,
            height: _kFrameSize,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.brandPrimary, width: 3),
              borderRadius: BorderRadius.circular(AppRadii.radiusXl),
            ),
          ),

          // Animated Scanning Line — moves top→bottom inside the frame
          SizedBox(
            width: _kFrameSize,
            height: _kFrameSize,
            child: AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, _) {
                final top = _scanLineAnimation.value * (_kFrameSize - 2);
                return Stack(
                  children: [
                    Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandPrimary.withValues(alpha: 0),
                              AppColors.brandPrimary,
                              AppColors.brandPrimary,
                              AppColors.brandPrimary.withValues(alpha: 0),
                            ],
                            stops: const [0.0, 0.15, 0.85, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.brandPrimary.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Helper Text
          const Positioned(
            bottom: 32,
            child: Text(
              'Đưa mã QR vào giữa khung để quét',
              style: TextStyle(
                color: AppColors.bgSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Flashlight Toggle
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, _) {
                  final torchState = state.torchState;
                  final isAvailable = torchState != TorchState.unavailable;

                  return IconButton(
                    icon: Icon(
                      torchState == TorchState.on
                          ? Icons.flash_on
                          : Icons.flash_off,
                      color: isAvailable ? AppColors.bgSurface : Colors.grey,
                      size: 24,
                    ),
                    onPressed: isAvailable
                        ? () async => _controller.toggleTorch()
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
