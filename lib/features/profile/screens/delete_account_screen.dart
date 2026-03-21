import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  int _step = 1; // 1 | 2 | 3
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _confirmedCheckbox = false;
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _goToStep(int step) => setState(() {
        _step = step;
        _passwordError = null;
      });

  Future<void> _submitDelete() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _passwordError = 'Vui lòng nhập mật khẩu');
      return;
    }

    final provider = context.read<ProfileProvider>();
    final success = await provider.deleteAccount(password: password);
    if (!mounted) return;

    if (success) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.login, (route) => false);
    } else {
      // Back to step 2 and show error
      setState(() {
        _step = 2;
        _passwordError =
            provider.errorMessage ?? 'Xác minh thất bại. Kiểm tra lại mật khẩu.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Xóa tài khoản thất bại'),
          backgroundColor: AppColors.critical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Xóa tài khoản'),
            backgroundColor: AppColors.critical,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: provider.isDeleting ? null : () {
                if (_step > 1) {
                  _goToStep(_step - 1);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          body: Column(
            children: [
              // ── Step indicator ─────────────────────────────────────
              _StepIndicator(currentStep: _step),

              // ── Step content ───────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _step == 1
                        ? _Step1(onContinue: () => _goToStep(2))
                        : _step == 2
                            ? _Step2(
                                controller: _passwordController,
                                obscure: _obscurePassword,
                                errorText: _passwordError,
                                onToggleObscure: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                onContinue: () {
                                  final pw =
                                      _passwordController.text.trim();
                                  if (pw.isEmpty) {
                                    setState(() => _passwordError =
                                        'Vui lòng nhập mật khẩu');
                                    return;
                                  }
                                  _goToStep(3);
                                },
                              )
                            : _Step3(
                                isDeleting: provider.isDeleting,
                                checked: _confirmedCheckbox,
                                onCheckChanged: (v) => setState(
                                    () => _confirmedCheckbox = v ?? false),
                                onDelete: _confirmedCheckbox && !provider.isDeleting
                                    ? _submitDelete
                                    : null,
                              ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _Dot(step: 1, current: currentStep, label: 'Xác nhận'),
          _Line(active: currentStep >= 2),
          _Dot(step: 2, current: currentStep, label: 'Mật khẩu'),
          _Line(active: currentStep >= 3),
          _Dot(step: 3, current: currentStep, label: 'Hoàn tất'),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int step;
  final int current;
  final String label;

  const _Dot({required this.step, required this.current, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDone = current > step;
    final isActive = current == step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone || isActive
                  ? AppColors.critical
                  : AppColors.strokeSoft,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive || isDone
                  ? AppColors.critical
                  : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final bool active;
  const _Line({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 2,
      color: active ? AppColors.critical.withValues(alpha: 0.5) : AppColors.strokeSoft,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 – Confirm Intent
// ─────────────────────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final VoidCallback onContinue;
  const _Step1({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large warning icon
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppStateColors.criticalBg,
              border: Border.all(
                  color: AppColors.critical.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(Icons.warning_amber_rounded,
                size: 44, color: AppColors.critical),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Bạn sắp xóa tài khoản',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.critical,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Warning list
        _WarningItem(
            icon: Icons.hourglass_bottom_outlined,
            text:
                'Tài khoản và toàn bộ dữ liệu sẽ bị xóa vĩnh viễn sau 30 ngày.'),
        const SizedBox(height: 10),
        _WarningItem(
            icon: Icons.no_accounts_outlined,
            text: 'Trong 30 ngày này bạn có thể đăng nhập để khôi phục.'),
        const SizedBox(height: 10),
        _WarningItem(
            icon: Icons.cloud_off_outlined,
            text:
                'Dữ liệu sức khoẻ, lịch sử đo và thông tin gia đình sẽ bị xóa hoàn toàn.'),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tôi hiểu, tiếp tục',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.strokeSoft),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hủy, giữ tài khoản',
                style: TextStyle(fontSize: 16, color: Color(0xFF5B7288))),
          ),
        ),
      ],
    );
  }
}

class _WarningItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _WarningItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStateColors.criticalBg,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.critical.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.critical, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF5B1A1A)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 – Enter Password
// ─────────────────────────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final String? errorText;
  final VoidCallback onToggleObscure;
  final VoidCallback onContinue;

  const _Step2({
    required this.controller,
    required this.obscure,
    required this.errorText,
    required this.onToggleObscure,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppStateColors.criticalBg,
              border: Border.all(
                  color: AppColors.critical.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(Icons.lock_person_outlined,
                size: 40, color: AppColors.critical),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nhập mật khẩu để xác minh',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF12304A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Chúng tôi cần xác minh danh tính của bạn trước khi xóa tài khoản.',
          style: TextStyle(fontSize: 14, color: Color(0xFF5B7288)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Mật khẩu hiện tại',
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                  size: 20),
              onPressed: onToggleObscure,
            ),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.critical, width: 2),
            ),
            errorText: errorText,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tiếp tục',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 – Final Confirmation with Checkbox
// ─────────────────────────────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final bool isDeleting;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;
  final VoidCallback? onDelete;

  const _Step3({
    required this.isDeleting,
    required this.checked,
    required this.onCheckChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppStateColors.criticalBg,
              border: Border.all(
                  color: AppColors.critical.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(Icons.delete_forever_outlined,
                size: 42, color: AppColors.critical),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Xác nhận lần cuối',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF12304A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Đánh dấu vào ô bên dưới để xác nhận bạn đã hiểu rõ hậu quả.',
          style: TextStyle(fontSize: 14, color: Color(0xFF5B7288)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Checkbox confirmation
        Container(
          decoration: BoxDecoration(
            color: AppStateColors.criticalBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.critical.withValues(alpha: checked ? 0.5 : 0.2)),
          ),
          child: CheckboxListTile(
            value: checked,
            onChanged: onCheckChanged,
            activeColor: AppColors.critical,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Tôi hiểu rằng toàn bộ dữ liệu sức khoẻ, lịch sử đo và thông tin gia đình của tôi sẽ bị xóa vĩnh viễn sau 30 ngày.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  checked ? AppColors.critical : AppColors.critical.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Xóa tài khoản vĩnh viễn',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        if (!checked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Vui lòng đánh dấu xác nhận để tiếp tục.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.critical.withValues(alpha: 0.7)),
            ),
          ),
      ],
    );
  }
}
