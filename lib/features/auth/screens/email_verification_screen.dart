import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
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
          backgroundColor: AppColors.success,
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
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.critical));
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
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi gửi mã. Vui lòng thử lại.'),
          backgroundColor: AppColors.critical,
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
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.strokeSoft, width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.brandPrimary, width: 2),
      borderRadius: BorderRadius.circular(AppRadii.radiusMd),
      color: AppColors.bgSurface,
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.critical, width: 2),
      color: AppStateColors.criticalBg,
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: AppColors.bgSurface,
      border: Border.all(color: AppColors.brandPrimaryLight, width: 1),
    );

    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: AppColors.brandPrimary),
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
                          color: AppColors.brandPrimaryLight.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          size: 72,
                          color: AppColors.brandPrimary,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds)
                          .fade(duration: 500.ms),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Xác thực Email',
                        style: AppTextStyles.displayCompact.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 16),

                      // Subtitle
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'Vui lòng nhập mã 6 số được gửi đến\n'),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
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
                            style: TextStyle(color: AppColors.critical, fontSize: 13),
                          ).animate().fadeIn(),
                        ),

                      const SizedBox(height: 40),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.buttonHeight,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : handleVerify,
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
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                                    ? AppColors.bgPrimary
                                    : AppColors.brandPrimary.withAlpha(20),
                                borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                              ),
                              child: _isResendingToken
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.brandPrimary,
                                      ),
                                    )
                                  : Text(
                                      _resendCountdown > 0
                                          ? 'Gửi lại ($_resendCountdown s)'
                                          : 'Gửi lại',
                                      style: TextStyle(
                                        color: _resendCountdown > 0
                                            ? AppColors.textSecondary
                                            : AppColors.brandPrimary,
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
