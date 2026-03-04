import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class DebugVerifyScreen extends StatefulWidget {
  const DebugVerifyScreen({super.key});

  @override
  State<DebugVerifyScreen> createState() => _DebugVerifyScreenState();
}

class _DebugVerifyScreenState extends State<DebugVerifyScreen> {
  final TextEditingController tokenController = TextEditingController();
  bool _isVerifying = false;
  String? _resultMessage;

  Future<void> _handleVerify() async {
    if (tokenController.text.trim().isEmpty) {
      setState(() {
        _resultMessage = '⚠️ Vui lòng paste token từ email';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _resultMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyEmail(tokenController.text.trim());

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _resultMessage = success
          ? '✅ ${authProvider.message ?? "Xác thực thành công!"}'
          : '❌ ${authProvider.message ?? "Xác thực thất bại"}';
    });

    if (success) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.login,
            (route) => false,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Debug - Xác thực Email'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Hướng dẫn sử dụng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Mở email xác thực\n'
                    '2. Copy toàn bộ token (đoạn sau "token=")\n'
                    '3. Paste vào ô bên dưới\n'
                    '4. Click "Xác thực ngay"',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Token:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText:
                    'Paste token từ email vào đây...\n\n'
                    'Ví dụ: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: AppSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : _handleVerify,
                icon: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isVerifying ? 'Đang xác thực...' : '🚀 Xác thực ngay',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  ),
                ),
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _resultMessage!.startsWith('✅')
                      ? Colors.green.shade50
                      : _resultMessage!.startsWith('❌')
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _resultMessage!.startsWith('✅')
                        ? Colors.green
                        : _resultMessage!.startsWith('❌')
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
                child: Text(
                  _resultMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _resultMessage!.startsWith('✅')
                        ? Colors.green.shade900
                        : _resultMessage!.startsWith('❌')
                        ? Colors.red.shade900
                        : Colors.orange.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: Colors.amber.shade900,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lưu ý',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Token có hiệu lực trong 24 giờ\n'
                    '• Mỗi token chỉ sử dụng được 1 lần\n'
                    '• Sau khi xác thực thành công, hãy đăng nhập lại',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
