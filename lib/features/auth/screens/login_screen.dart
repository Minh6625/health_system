import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/constants/app_strings.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/models/user_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (success) {
      authProvider.clearMessage();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.dashboard,
        (route) => false,
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
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 70,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    AuthTextField(
                      label: 'Email',
                      icon: Icons.email,
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) return 'Vui lòng nhập email';
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(input)) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      label: 'Password',
                      icon: Icons.lock,
                      controller: passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : handleLogin,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('LOGIN'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chưa có tài khoản? '),
                        GestureDetector(
                          onTap: openRegister,
                          child: const Text(
                            AppStrings.register,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
