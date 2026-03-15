import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Screen for entering a new password after OTP verification.
/// Receives [email] and [code] from [ResetOtpVerificationScreen].
class ResetPasswordScreen extends StatefulWidget {
  final String? code;
  final String? email;

  const ResetPasswordScreen({super.key, this.code, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final AuthRepository _authRepository = AuthRepository();

  // Real-time password strength flags (same rules as RegisterScreen)
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _isPasswordComplete = false;

  // Confirm-password live match state
  bool _isConfirmPasswordMatch = true;
  bool _isConfirmPasswordPristine = true;

  bool _isResetting = false;
  bool _resetSuccess = false;
  String _statusMessage = '';
  bool _isError = false;

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    final email = widget.email ?? '';
    final code = widget.code ?? '';
    if (email.isEmpty || code.isEmpty) {
      setState(() {
        _statusMessage = 'Không tìm thấy thông tin xác thực. Vui lòng quay lại.';
        _isError = true;
      });
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    setState(() {
      _isResetting = true;
      _statusMessage = 'Đang đặt lại mật khẩu...';
    });

    try {
      final response = await _authRepository.resetPassword(
        email,
        code,
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
        setState(() => _isError = true);
        Future.delayed(400.ms, () {
          if (mounted) setState(() => _isError = false);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_statusMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isResetting = false;
        _statusMessage = 'Lỗi: ${e.toString()}';
        _isError = true;
      });
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusMessage)),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    passwordController.addListener(_validatePassword);
    confirmPasswordController.addListener(_validateConfirmPassword);
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  void _validatePassword() {
    final pass = passwordController.text;
    setState(() {
      _hasMinLength = pass.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
      _hasLowercase = RegExp(r'[a-z]').hasMatch(pass);
      _hasNumber = RegExp(r'\d').hasMatch(pass);
      _hasSpecialChar =
          RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass);
      _isPasswordComplete = _hasMinLength &&
          _hasUppercase &&
          _hasLowercase &&
          _hasNumber &&
          _hasSpecialChar;
    });
    if (!_isConfirmPasswordPristine) _validateConfirmPassword();
  }

  void _validateConfirmPassword() {
    final confirm = confirmPasswordController.text;
    setState(() {
      _isConfirmPasswordPristine = confirm.isEmpty;
      _isConfirmPasswordMatch =
          confirm.isEmpty || confirm == passwordController.text;
    });
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.primary),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        (Scaffold.of(context).appBarMaxHeight ?? 0),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 1),
                        if (_resetSuccess)
                          _buildSuccessView()
                        else
                          _buildPasswordForm(),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 72,
              color: AppColors.primary,
            ),
          )
              .animate(
                  onPlay: (controller) =>
                      controller.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds)
              .fade(duration: 500.ms),

          const SizedBox(height: 32),

          // Title
          const Text(
            'Mật Khẩu Mới',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 12),

          // Subtitle
          const Text(
            'Vui lòng nhập mật khẩu an toàn.\nNên bao gồm chữ, số và ký tự đặc biệt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 32),

          // ── Mật khẩu mới ──────────────────────────────────────────
          AuthTextField(
            label: 'Mật khẩu mới',
            icon: Icons.lock_outline,
            controller: passwordController,
            focusNode: _passwordFocusNode,
            obscureText: true,
            textInputAction: TextInputAction.next,
            borderColor: _isPasswordComplete ? Colors.green : null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập mật khẩu mới';
              }
              if (value.length < 8) {
                return 'Mật khẩu phải có ít nhất 8 ký tự';
              }
              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return 'Mật khẩu phải chứa ít nhất 1 ký tự in hoa';
              }
              if (!RegExp(r'[a-z]').hasMatch(value)) {
                return 'Mật khẩu phải chứa ít nhất 1 ký tự in thường';
              }
              if (!RegExp(r'\d').hasMatch(value)) {
                return 'Mật khẩu phải chứa ít nhất 1 chữ số';
              }
              if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                return 'Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt';
              }
              return null;
            },
          ),

          // Checklist yêu cầu mật khẩu – hiện khi field được focus
          if (_passwordFocusNode.hasFocus) ...[
            const SizedBox(height: 8),
            _buildRequirementRow('Ít nhất 8 ký tự', _hasMinLength),
            _buildRequirementRow('Ít nhất 1 chữ in hoa', _hasUppercase),
            _buildRequirementRow('Ít nhất 1 chữ in thường', _hasLowercase),
            _buildRequirementRow('Ít nhất 1 chữ số', _hasNumber),
            _buildRequirementRow(
                'Ít nhất 1 ký tự đặc biệt', _hasSpecialChar),
          ],

          const SizedBox(height: 20),

          // ── Xác nhận mật khẩu ─────────────────────────────────────
          AuthTextField(
            label: 'Xác nhận mật khẩu',
            icon: Icons.lock_reset_outlined,
            controller: confirmPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            borderColor: _isConfirmPasswordPristine
                ? null
                : (_isConfirmPasswordMatch ? Colors.green : Colors.red),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng xác nhận mật khẩu';
              }
              if (value != passwordController.text) {
                return 'Mật khẩu xác nhận không khớp';
              }
              return null;
            },
          ),

          // Inline error khi không khớp
          if (!_isConfirmPasswordPristine && !_isConfirmPasswordMatch)
            const Padding(
              padding: EdgeInsets.only(top: 6.0, left: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mật khẩu xác nhận không khớp',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),

          const SizedBox(height: 40),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: _isResetting ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isResetting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'XÁC NHẬN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      )
          .animate(target: _isError ? 1 : 0)
          .shake(hz: 8, curve: Curves.easeInOutCubic, duration: 400.ms),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 80,
            color: Colors.green,
          ),
        )
            .animate()
            .scaleXY(
                begin: 0, end: 1, duration: 500.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 32),

        const Text(
          'Thành Công!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        const Text(
          'Mật khẩu của bạn đã được thay đổi. Bạn có thể đăng nhập ngay bây giờ.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 48),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync, color: AppColors.primary, size: 20)
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 2.seconds),
            const SizedBox(width: 8),
            const Text(
              'Chuyển hướng trong 3 giây...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 32),

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
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'ĐĂNG NHẬP NGAY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }
}
