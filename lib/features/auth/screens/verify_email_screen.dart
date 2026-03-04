import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/screens/debug_verify_screen.dart';
import 'package:provider/provider.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token;
  final String? email;

  const VerifyEmailScreen({super.key, this.token, this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isVerifying = false;
  bool _isWaiting = true;
  String _statusMessage = 'Vui lòng kiểm tra email để xác thực';

  @override
  void initState() {
    super.initState();
    // Auto-verify if token provided via deep link
    if (widget.token != null && widget.token!.isNotEmpty) {
      setState(() {
        _isWaiting = false;
        _isVerifying = true;
        _statusMessage = 'Đang xác thực email...';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleVerifyEmail();
      });
    } else {
      // No token - waiting mode (show instructions and wait for deep link)
      setState(() {
        _isWaiting = true;
        _isVerifying = false;
        _statusMessage = 'Vui lòng kiểm tra email để xác thực';
      });
    }
  }

  Future<void> _handleVerifyEmail() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _isWaiting = false;
        _isVerifying = false;
        _statusMessage = 'Mã xác thực không hợp lệ';
      });
      return;
    }

    setState(() {
      _isWaiting = false;
      _isVerifying = true;
      _statusMessage = 'Đang xác thực email...';
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyEmail(widget.token!);

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _statusMessage =
          authProvider.message ??
          (success ? 'Xác thực thành công!' : 'Xác thực thất bại');
    });

    if (success) {
      // Navigate to login after successful verification
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực Email'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Icon(
                    _isWaiting
                        ? Icons.mail_outline
                        : _isVerifying
                        ? Icons.pending_outlined
                        : (_statusMessage.contains('thành công'))
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 80,
                    color: _isWaiting
                        ? AppColors.primary
                        : _isVerifying
                        ? AppColors.primary
                        : (_statusMessage.contains('thành công'))
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    _isWaiting
                        ? 'Xác thực Email'
                        : _isVerifying
                        ? 'Đang xác thực...'
                        : (_statusMessage.contains('thành công'))
                        ? 'Xác thực thành công!'
                        : 'Xác thực thất bại',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),

                  // Waiting mode
                  if (_isWaiting)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const Text(
                            'Vui lòng kiểm tra email để xác thực',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          if (widget.email != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              widget.email!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
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
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Hướng dẫn',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '1. Mở ứng dụng email trên điện thoại\n'
                                  '2. Tìm email từ Health Guard\n'
                                  '3. Click vào link xác thực\n'
                                  '4. App sẽ tự động mở và kích hoạt',
                                  style: TextStyle(fontSize: 14, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Đang chờ xác thực...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Debug button for when deep link doesn't work
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DebugVerifyScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bug_report, size: 16),
                            label: const Text(
                              '🔧 Debug - Test xác thực (nếu link không hoạt động)',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  // Loading indicator when verifying
                  else if (_isVerifying)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          'Đang xác thực...\nVui lòng đợi trong giây lát...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    )
                  // Result message
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Action button - only show if failed
                          if (!_statusMessage.contains('thành công'))
                            SizedBox(
                              width: double.infinity,
                              height: AppSizes.buttonHeight,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRouter.login,
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.cardRadius,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Quay lại đăng nhập',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
