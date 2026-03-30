import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _isError = false;

  Future<void> handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authRepository.forgotPassword(
        emailController.text.trim(),
      );

      if (!mounted) return;

      if (response.success) {
        // Navigate to reset password waiting screen
        Navigator.pushReplacementNamed(
          context,
          AppRouter.verifyResetOtp,
          arguments: {'email': emailController.text.trim()},
        );
      } else {
        setState(() => _isError = true);
        Future.delayed(400.ms, () {
          if (mounted) setState(() => _isError = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
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
                    minHeight: constraints.maxHeight - Scaffold.of(context).appBarMaxHeight!,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 1),
                          // Icon Container
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 72,
                              color: AppColors.primary,
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds)
                              .fade(duration: 500.ms),

                          const SizedBox(height: 32),

                          // Title
                          const Text(
                            'Quên Mật Khẩu',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 16),

                          // Subtitle
                          const Text(
                            'Nhập email của bạn để nhận liên kết\nđặt lại mật khẩu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 48),

                          // Email Input
                          AuthTextField(
                            label: 'Email',
                            icon: Icons.email_outlined,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value.trim())) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          )
                              .animate(target: _isError ? 1 : 0)
                              .shake(hz: 8, curve: Curves.easeInOutCubic, duration: 400.ms)
                              .animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 32),

                          // Send Link Button
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : handleForgotPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'GỬI LIÊN KẾT',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 24),

                          // Back to login
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text(
                                'Quay lại đăng nhập',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 600.ms),

                          const Spacer(flex: 3),
                        ],
                      ),
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
}
