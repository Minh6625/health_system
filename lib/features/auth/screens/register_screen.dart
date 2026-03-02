import 'package:flutter/material.dart';
import 'package:health_system/core/constants/app_colors.dart';
import 'package:health_system/core/constants/app_sizes.dart';
import 'package:health_system/core/utils/validators.dart';
import 'package:health_system/features/auth/models/user_model.dart';
import 'package:health_system/features/auth/providers/auth_provider.dart';
import 'package:health_system/features/auth/widgets/auth_text_field.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  Future<void> handleRegister() async {
    final authProvider = context.read<AuthProvider>();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (!Validators.isValidEmail(email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email không hợp lệ')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
      );
      return;
    }

    final user = UserModel(email: email, password: password);
    final success = await authProvider.register(user);

    if (!mounted) {
      return;
    }

    final message = authProvider.message ?? 'Đăng ký thất bại';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (success) {
      authProvider.clearMessage();
      Navigator.pop(context, email);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          children: [
            AuthTextField(
              label: 'Email',
              icon: Icons.email,
              controller: emailController,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Mật khẩu',
              icon: Icons.lock,
              controller: passwordController,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'Xác nhận mật khẩu',
              icon: Icons.lock_outline,
              controller: confirmPasswordController,
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: authProvider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ĐĂNG KÝ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
