import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/models/user_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  
  bool _isError = false;

  Future<void> openRegister() async {
    final registeredEmail = await Navigator.pushNamed(
      context,
      AppRouter.register,
    );

    if (registeredEmail is String && registeredEmail.isNotEmpty) {
      emailController.text = registeredEmail;
    }
  }

  Future<void> handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _isError = true);
      // Reset error state after animation finishes so it can trigger again
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final user = UserModel(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    final success = await authProvider.login(user);

    if (!mounted) {
      return;
    }

    final message = authProvider.message;
    if (message == null) {
      return;
    }

    // Check if login failed due to unverified email
    if (!success && message.toLowerCase().contains('xác thực email')) {
      // Show error message with option to go to verification screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng xác thực email'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Xác thực',
            textColor: AppColors.bgSurface,
            onPressed: () {
              // Resend verification email first
              _resendVerification(emailController.text.trim());
              // Then navigate to verification waiting screen
              Navigator.pushNamed(
                context,
                AppRouter.verifyEmail,
                arguments: {'email': emailController.text.trim()},
              );
            },
          ),
        ),
      );
    } else if (!success) {
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.critical));
    }

    if (success) {
      authProvider.clearMessage();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.dashboard,
        (route) => false,
      );
    }
  }

  Future<void> _resendVerification(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập email')));
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationToken(email);

    if (!mounted) return;

    final message = authProvider.message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.success : null,
        ),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    FocusScope.of(context).unfocus();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgSurface,
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.brandPrimaryLight, AppColors.bgSurface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.screenPadding,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 1),
                          // Logo Section
                          Center(
                            child: Container(
                              width: 200,
                              height: 160,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
                               ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadii.radiusXxl),
                                child: Image.asset(
                                  'assets/images/logo_rmbg.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .scaleXY(begin: 0.98, end: 1.0, duration: 1.seconds, curve: Curves.easeOutBack)
                              .fade(duration: 500.ms),
                              
                          const SizedBox(height: 24),
                          
                          // Header Section
                          Center(
                            child: Text(
                              'Đăng Nhập',
                              style: AppTextStyles.displayCompact.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                          
                          const SizedBox(height: 40),
                          
                          // Inputs wrapped in an animated shaking container if error
                          Column(
                            children: [
                              // Email Input
                              AuthTextField(
                                label: 'Email',
                                icon: Icons.email_outlined,
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập email';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                              
                              const SizedBox(height: 20),
                              
                              // Password Input
                              AuthTextField(
                                label: 'Mật khẩu',
                                icon: Icons.lock_outline,
                                controller: passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Vui lòng nhập mật khẩu';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
                            ],
                          ).animate(target: _isError ? 1 : 0).shake(hz: 8, curve: Curves.easeInOutCubic, duration: 400.ms),

                          const SizedBox(height: 8),
                          
                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRouter.forgotPassword,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.brandPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                'Quên mật khẩu?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 500.ms),
                          
                          const SizedBox(height: 24),
                          
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.buttonHeight,
                            child: ElevatedButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.bgSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                                ),
                                elevation: 0,
                              ),
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: AppColors.bgSurface,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'ĐĂNG NHẬP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                          
                          const SizedBox(height: 32),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Chưa có tài khoản? ',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: openRegister,
                                child: const Text(
                                  'Đăng ký ngay',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 700.ms),
                          
                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ),
        ),
      ),
    );
  }
}
