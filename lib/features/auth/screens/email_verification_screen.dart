import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String? code;

  const EmailVerificationScreen({super.key, required this.email, this.code});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _isResendingToken = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  bool _isError = false;

  @override
  void initState() {
    super.initState();
    if (widget.code != null && widget.code!.isNotEmpty) {
      _pinController.text = widget.code!;
    }

    // Wait for the animation to finish, then focus the OTP field
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _pinController.text.length < 6) {
        _pinFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _resendCountdown = 60; // 60 seconds countdown
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> handleVerify() async {
    final token = _pinController.text.trim();
    if (token.length < 6) {
      setState(() => _isError = true);
      return;
    }

    setState(() => _isError = false);
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.verifyEmail(widget.email, token);

    if (!mounted) return;

    if (success) {
      authProvider.clearMessage();
      // Show success briefly before navigating
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xác thực thành công!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.login,
        (route) => false,
      );
    } else {
      setState(() => _isError = true);
      final message = authProvider.message ?? 'Mã xác thực không hợp lệ';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    }
  }

  Future<void> handleResendToken() async {
    if (_resendCountdown > 0) return;

    setState(() => _isResendingToken = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationToken(widget.email);

    if (!mounted) return;

    setState(() => _isResendingToken = false);

    if (success) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã xác thực mới đã được gửi'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi gửi mã. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.red.shade400, width: 2),
      color: Colors.red.shade50,
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: Colors.white,
      border: Border.all(color: AppColors.primaryLight, width: 1),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
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
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Mail Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
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
                        'Xác thực Email',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 16),

                      // Subtitle
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'Vui lòng nhập mã 6 số được gửi đến\n'),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 48),

                      // Pinput OTP Field
                      Pinput(
                        length: 6,
                        controller: _pinController,
                        focusNode: _pinFocusNode,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        errorPinTheme: errorPinTheme,
                        forceErrorState: _isError,
                        pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                        showCursor: true,
                        onCompleted: (pin) {
                          if (pin.length == 6) {
                            handleVerify();
                          }
                        },
                        onChanged: (value) {
                          if (_isError) {
                            setState(() => _isError = false);
                          }
                        },
                      )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.2, end: 0)
                          .shake(hz: 8, curve: Curves.easeInOutCubic, duration: 400.ms),
                      
                      if (_isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            'Mã xác thực không hợp lệ',
                            style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                          ).animate().fadeIn(),
                        ),

                      const SizedBox(height: 40),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : handleVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: authProvider.isLoading
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
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 24),

                      // Resend Token
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Chưa nhận được mã? ',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: _resendCountdown > 0 || _isResendingToken
                                ? null
                                : handleResendToken,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _resendCountdown > 0
                                    ? Colors.grey.shade100
                                    : AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isResendingToken
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Text(
                                      _resendCountdown > 0
                                          ? 'Gửi lại ($_resendCountdown s)'
                                          : 'Gửi lại',
                                      style: TextStyle(
                                        color: _resendCountdown > 0
                                            ? Colors.grey
                                            : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 600.ms),
                      
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
