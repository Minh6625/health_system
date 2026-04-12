import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Screen for verifying the 6-digit OTP sent to the user's email
/// as part of the password reset flow. On success, navigates to
/// [ResetPasswordScreen] where the user enters a new password.
class ResetOtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? code;

  const ResetOtpVerificationScreen({
    super.key,
    required this.email,
    this.code,
  });

  @override
  State<ResetOtpVerificationScreen> createState() =>
      _ResetOtpVerificationScreenState();
}

class _ResetOtpVerificationScreenState
    extends State<ResetOtpVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  final AuthRepository _authRepository = AuthRepository();

  bool _isVerifying = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    // Auto-fill pin AFTER the first frame so that Pinput's onCompleted
    // listener does not fire synchronously during initState (which would
    // trigger _handleVerifyOtp automatically without user interaction).
    if (widget.code != null && widget.code!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pinController.text = widget.code!;
        }
      });
    }

    // Focus the OTP field after animation only when no code was pre-filled
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
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _pinController.text.trim();
    if (otp.length < 6) {
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _isError = false;
    });

    try {
      final response = await _authRepository.verifyResetOtp(widget.email, otp);

      if (!mounted) return;

      setState(() => _isVerifying = false);

      if (response.success) {
        // OTP verified — navigate to password reset screen
        Navigator.pushReplacementNamed(
          context,
          AppRouter.resetPassword,
          arguments: {'email': widget.email, 'code': otp},
        );
      } else {
        setState(() => _isError = true);
        Future.delayed(400.ms, () {
          if (mounted) setState(() => _isError = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isError = true;
      });
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      // Animated Lock Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimaryLight.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 72,
                          color: AppColors.brandPrimary,
                        ),
                      )
                          .animate(
                              onPlay: (controller) =>
                                  controller.repeat(reverse: true))
                          .scaleXY(
                              begin: 0.95, end: 1.05, duration: 2.seconds)
                          .fade(duration: 500.ms),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        'Xác Nhận OTP',
                        style: AppTextStyles.displayCompact.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 16),

                      // Subtitle with email
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                                text:
                                    'Mã xác thực 6 số đã được gửi đến\n'),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.2, end: 0),

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
                        pinputAutovalidateMode:
                            PinputAutovalidateMode.onSubmit,
                        showCursor: true,
                        onCompleted: (pin) {
                          if (pin.length == 6) {
                            _handleVerifyOtp();
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
                          .shake(
                              hz: 8,
                              curve: Curves.easeInOutCubic,
                              duration: 400.ms),

                      if (_isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(
                            'Mã xác thực không hợp lệ',
                            style: TextStyle(
                                color: AppColors.critical, fontSize: 13),
                          ).animate().fadeIn(),
                        ),

                      const SizedBox(height: 40),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: AppSizes.buttonHeight,
                        child: ElevatedButton(
                          onPressed:
                              _isVerifying ? null : _handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: AppColors.bgSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.radiusLg),
                            ),
                            elevation: 0,
                          ),
                          child: _isVerifying
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
                      )
                          .animate()
                          .fadeIn(delay: 500.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 24),

                      // Back to login
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text(
                            'Quay lại đăng nhập',
                            style: TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
