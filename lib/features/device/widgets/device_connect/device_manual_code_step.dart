import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_connect_provider.dart';

class DeviceManualCodeStep extends StatefulWidget {
  const DeviceManualCodeStep({super.key});

  @override
  State<DeviceManualCodeStep> createState() => _DeviceManualCodeStepState();
}

class _DeviceManualCodeStepState extends State<DeviceManualCodeStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceConnectProvider>();
    final isVerifying = provider.state == DeviceConnectState.verifying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nhập mã thiết bị',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF12304A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mã gồm 6-8 ký tự trên vỏ hộp hoặc trong phần cài đặt của đồng hồ.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF5B7288),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _controller,
            enabled: !isVerifying,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'VD: A1B2C3',
              hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 0),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isVerifying ? null : () {
              provider.verifyCode(_controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: isVerifying 
                ? const SizedBox(
                    height: 24, 
                    width: 24, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text(
                    'Kiểm tra mã',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
