import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/screens/debug_reset_password_screen.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:jwt_decode/jwt_decode.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? resetToken;
  final String? email;

  const ResetPasswordScreen({super.key, this.resetToken, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  bool _isResetting = false;
  bool _isWaiting = true;
  bool _resetSuccess = false;
  String _statusMessage = 'Vui lòng kiểm tra email để đặt lại mật khẩu';

  @override
  void initState() {
    super.initState();
    // Auto-reset if token provided via deep link
    if (widget.resetToken != null && widget.resetToken!.isNotEmpty) {
      // Validate token before showing form
      try {
        if (Jwt.isExpired(widget.resetToken!)) {
          // Token expired
          setState(() {
            _isWaiting = true;
            _statusMessage =
                '❌ Token đã hết hạn (15 phút). Vui lòng yêu cầu gửi lại email.';
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Token đã hết hạn. Vui lòng yêu cầu gửi lại email quên mật khẩu.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          });
        } else {
          // Token valid, show form
          setState(() {
            _isWaiting = false;
          });
        }
      } catch (e) {
        // Invalid token format
        setState(() {
          _isWaiting = true;
          _statusMessage = '❌ Token không hợp lệ';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Token không hợp lệ. Vui lòng kiểm tra lại email hoặc yêu cầu gửi lại.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        });
      }
    } else {
      // No token - waiting mode (show instructions and wait for deep link)
      setState(() {
        _isWaiting = true;
        _isResetting = false;
        _statusMessage = 'Vui lòng kiểm tra email để đặt lại mật khẩu';
      });
    }
  }

  Future<void> handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.resetToken == null || widget.resetToken!.isEmpty) {
      setState(() {
        _statusMessage = 'Token không hợp lệ';
      });
      return;
    }

    setState(() {
      _isResetting = true;
      _statusMessage = 'Đang đặt lại mật khẩu...';
    });

    try {
      final response = await _authRepository.resetPassword(
        widget.resetToken!,
        passwordController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isResetting = false;
        _resetSuccess = response.success;
        _statusMessage = response.message;
      });

      if (response.success) {
        // Auto navigate to login after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRouter.login,
              (route) => false,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_statusMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isResetting = false;
        _statusMessage = 'Lỗi: ${e.toString()}';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_statusMessage)));
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt Lại Mật Khẩu'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
              child: _resetSuccess
                  ? _buildSuccessView()
                  : _isWaiting
                  ? _buildWaitingView()
                  : _buildFormView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mail_outline, size: 80, color: AppColors.primary),
        const SizedBox(height: 20),
        const Text(
          'Đặt Lại Mật Khẩu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Text(
                'Vui lòng kiểm tra email để đặt lại mật khẩu',
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
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
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
                      '3. Click vào link đặt lại mật khẩu\n'
                      '4. App sẽ tự động mở và cho phép đặt mật khẩu mới',
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
                      'Đang chờ đặt lại mật khẩu...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
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
                      builder: (context) => const DebugResetPasswordScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report, size: 16),
                label: const Text(
                  '🔧 Debug - Đặt lại mật khẩu thủ công (nếu link không hoạt động)',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Liên kết có hiệu lực trong 15 phút',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_open_rounded,
            size: 70,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Đặt Mật Khẩu Mới',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập mật khẩu mới của bạn (tối thiểu 6 ký tự)',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          AuthTextField(
            label: 'Mật khẩu mới',
            icon: Icons.lock,
            controller: passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập mật khẩu mới';
              }
              if (value.trim().length < 6) {
                return 'Mật khẩu phải có ít nhất 6 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          AuthTextField(
            label: 'Xác nhận mật khẩu',
            icon: Icons.lock_outline,
            controller: confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng xác nhận mật khẩu';
              }
              if (value.trim() != passwordController.text.trim()) {
                return 'Mật khẩu không khớp';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: _isResetting ? null : handleResetPassword,
              child: _isResetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('ĐẶT LẠI MẬT KHẨU'),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Liên kết đặt lại mật khẩu có hiệu lực trong 15 phút',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          'Đặt lại mật khẩu thành công!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Mật khẩu của bạn đã được thay đổi.\nBạn có thể đăng nhập ngay bây giờ.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Chuyển hướng trong 3 giây...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
            child: const Text('ĐĂNG NHẬP NGAY'),
          ),
        ),
      ],
    );
  }
}
