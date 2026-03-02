import 'package:flutter/material.dart';
import 'package:health_system/core/constants/app_colors.dart';
import 'package:health_system/core/constants/app_sizes.dart';
import 'package:health_system/core/routes/app_router.dart';
import 'package:health_system/features/auth/providers/auth_provider.dart';
import 'package:health_system/features/auth/widgets/auth_text_field.dart';
import 'package:provider/provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController tokenController = TextEditingController();
  bool _isResendingToken = false;

  Future<void> handleVerify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final token = tokenController.text.trim();

    final success = await authProvider.verifyEmail(token);

    if (!mounted) {
      return;
    }

    final message = authProvider.message ?? 'Xác thực thất bại';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (success) {
      authProvider.clearMessage();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.login,
        (route) => false,
      );
    }
  }

  Future<void> handleResendToken() async {
    setState(() => _isResendingToken = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationToken(widget.email);

    if (!mounted) {
      setState(() => _isResendingToken = false);
      return;
    }

    final message = success
        ? 'Token xác thực đã được gửi lại'
        : 'Lỗi gửi token. Vui lòng thử lại';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    setState(() => _isResendingToken = false);
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác thực Email'),
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mail_outline,
                      size: 60,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Xác thực Email',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chúng tôi đã gửi token xác thực đến\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    AuthTextField(
                      label: 'Token Xác thực',
                      icon: Icons.vpn_key,
                      controller: tokenController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập token xác thực';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : handleVerify,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('XÁC THỰC'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isResendingToken ? null : handleResendToken,
                      child: _isResendingToken
                          ? const Text('Đang gửi...')
                          : const Text(
                              'Không nhận được token? Gửi lại',
                              style: TextStyle(color: AppColors.primary),
                            ),
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
