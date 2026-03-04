import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:jwt_decode/jwt_decode.dart';

class DebugResetPasswordScreen extends StatefulWidget {
  const DebugResetPasswordScreen({super.key});

  @override
  State<DebugResetPasswordScreen> createState() =>
      _DebugResetPasswordScreenState();
}

class _DebugResetPasswordScreenState extends State<DebugResetPasswordScreen> {
  final TextEditingController tokenController = TextEditingController();
  bool _isValidating = false;

  Future<void> _handleSubmitToken() async {
    final token = tokenController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Vui lòng paste token từ email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isValidating = true;
    });

    try {
      // Validate JWT token format and expiry
      if (!Jwt.isExpired(token)) {
        // Token is valid, navigate to reset password screen
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRouter.resetPassword,
          arguments: {'token': token},
        );
      } else {
        // Token expired
        if (!mounted) return;
        setState(() {
          _isValidating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Token đã hết hạn (15 phút). Vui lòng yêu cầu gửi lại email.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Invalid token format
      if (!mounted) return;
      setState(() {
        _isValidating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Token không hợp lệ: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
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
        title: const Text('🔧 Debug - Nhập Token'),
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
                    '1. Mở email đặt lại mật khẩu\n'
                    '2. Copy toàn bộ token (đoạn sau "token=")\n'
                    '3. Paste vào ô bên dưới\n'
                    '4. Click "Tiếp tục" để chuyển sang form đặt mật khẩu',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reset Token:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenController,
              maxLines: 10,
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
            const SizedBox(height: 24),
            SizedBox(
              height: AppSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: _isValidating ? null : _handleSubmitToken,
                icon: _isValidating
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
                    : const Icon(Icons.arrow_forward, size: 24),
                label: Text(
                  _isValidating ? 'Đang kiểm tra...' : '🚀 Tiếp tục',
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
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Lưu ý quan trọng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Token reset chỉ có hiệu lực trong 15 phút\n'
                    '• Nếu hết hạn, vui lòng yêu cầu gửi lại email\n'
                    '• Sau khi paste token, bạn sẽ chuyển sang form đặt mật khẩu mới\n'
                    '• Màn hình này chỉ dùng khi deep link không hoạt động',
                    style: TextStyle(fontSize: 12, height: 1.5),
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
