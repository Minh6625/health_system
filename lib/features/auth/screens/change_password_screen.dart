import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/core/constants/app_colors.dart';
import 'package:healthguard/core/constants/app_sizes.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/widgets/auth_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentCtrl = TextEditingController();
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _isError = false;
  bool _success = false;

  // ── Password strength ─────────────────────────────────────────────────────
  _PasswordStrength _strength = _PasswordStrength.empty;
  static _PasswordStrength _evaluateStrength(String pw) {
    if (pw.isEmpty) return _PasswordStrength.empty;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pw)) score++;
    if (score <= 1) return _PasswordStrength.weak;
    if (score <= 3) return _PasswordStrength.moderate;
    return _PasswordStrength.strong;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authRepository.changePassword(
        _currentCtrl.text.trim(),
        _newCtrl.text.trim(),
      );

      if (!mounted) return;

      if (response.success) {
        setState(() => _success = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đổi mật khẩu thành công!'),
            backgroundColor: Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() => _isError = true);
        Future.delayed(400.ms, () {
          if (mounted) setState(() => _isError = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isError = true);
      Future.delayed(400.ms, () {
        if (mounted) setState(() => _isError = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen to new-password changes to update strength indicator
    _newCtrl.addListener(() {
      setState(() {
        _strength = _evaluateStrength(_newCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
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
                        (Scaffold.of(context).appBarMaxHeight ?? 56),
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 1),

                          // ── Animated Icon ────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _success
                                  ? Icons.check_circle_rounded
                                  : Icons.lock_rounded,
                              size: 72,
                              color: _success
                                  ? const Color(0xFF16A34A)
                                  : AppColors.primary,
                            ),
                          )
                              .animate(
                                  onPlay: (c) => c.repeat(reverse: true))
                              .scaleXY(
                                  begin: 0.95,
                                  end: 1.05,
                                  duration: 2.seconds)
                              .fade(duration: 500.ms),

                          const SizedBox(height: 32),

                          // ── Title ────────────────────────────────────────
                          const Text(
                            'Đổi Mật Khẩu',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 150.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 10),

                          // ── Subtitle ─────────────────────────────────────
                          const Text(
                            'Nhập mật khẩu hiện tại và tạo mật khẩu mới\nan toàn hơn cho tài khoản của bạn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 250.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 40),

                          // ── Current password ─────────────────────────────
                          AuthTextField(
                            label: 'Mật khẩu hiện tại',
                            icon: Icons.lock_outline,
                            controller: _currentCtrl,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập mật khẩu hiện tại';
                              }
                              return null;
                            },
                          )
                              .animate(target: _isError ? 1 : 0)
                              .shake(
                                  hz: 7,
                                  curve: Curves.easeInOutCubic,
                                  duration: 400.ms)
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 20),

                          // ── New password ──────────────────────────────────
                          AuthTextField(
                            label: 'Mật khẩu mới',
                            icon: Icons.lock_person_outlined,
                            controller: _newCtrl,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              final pw = v?.trim() ?? '';
                              if (pw.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                              if (pw.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                              if (pw == _currentCtrl.text.trim()) {
                                return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                              }
                              return null;
                            },
                          )
                              .animate()
                              .fadeIn(delay: 350.ms)
                              .slideY(begin: 0.2, end: 0),

                          // ── Strength indicator ────────────────────────────
                          if (_strength != _PasswordStrength.empty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _StrengthIndicator(strength: _strength),
                            ).animate().fadeIn(duration: 200.ms),

                          const SizedBox(height: 20),

                          // ── Confirm password ──────────────────────────────
                          AuthTextField(
                            label: 'Xác nhận mật khẩu mới',
                            icon: Icons.lock_reset_rounded,
                            controller: _confirmCtrl,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng xác nhận mật khẩu';
                              }
                              if (v.trim() != _newCtrl.text.trim()) {
                                return 'Mật khẩu không khớp';
                              }
                              return null;
                            },
                          )
                              .animate()
                              .fadeIn(delay: 400.ms)
                              .slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 32),

                          // ── Requirements hint ─────────────────────────────
                          _PasswordRequirementsHint()
                              .animate()
                              .fadeIn(delay: 450.ms),

                          const SizedBox(height: 24),

                          // ── CTA ───────────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.buttonHeight,
                            child: ElevatedButton(
                              onPressed:
                                  (_isLoading || _success) ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withAlpha(120),
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
                                  : _success
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'ĐÃ ĐỔI THÀNH CÔNG',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'ĐỔI MẬT KHẨU',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                            ),
                          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            child: const Text(
                              'Quay lại',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ).animate().fadeIn(delay: 550.ms),

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

// ── Password Strength ─────────────────────────────────────────────────────────

enum _PasswordStrength { empty, weak, moderate, strong }

class _StrengthIndicator extends StatelessWidget {
  final _PasswordStrength strength;
  const _StrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    final (label, color, filled) = switch (strength) {
      _PasswordStrength.weak => ('Yếu', Colors.red.shade600, 1),
      _PasswordStrength.moderate => ('Trung bình', Colors.orange.shade600, 2),
      _PasswordStrength.strong => ('Mạnh', const Color(0xFF16A34A), 3),
      _PasswordStrength.empty => ('', Colors.grey, 0),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 5,
                decoration: BoxDecoration(
                  color: i < filled ? color : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          child: Text('Độ mạnh: $label'),
        ),
      ],
    );
  }
}

// ── Requirements Hint ─────────────────────────────────────────────────────────

class _PasswordRequirementsHint extends StatelessWidget {
  const _PasswordRequirementsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text(
                'Yêu cầu mật khẩu:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Req('Tối thiểu 8 ký tự'),
          _Req('Khác với mật khẩu hiện tại'),
          _Req('Khuyến nghị: chữ hoa, số và ký tự đặc biệt'),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final String text;
  const _Req(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: Color(0xFF2563EB), fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E40AF),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
