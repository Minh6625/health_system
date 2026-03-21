import 'package:flutter/material.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

/// Màn hình xác nhận sau khi gửi SOS thành công.
/// Thay thế SnackBar để user yên tâm rằng đã gửi thành công.
/// Sau này nhận recipientCount từ API response.
class SosConfirmScreen extends StatefulWidget {
  /// Số người thân đã được thông báo
  final int recipientCount;

  const SosConfirmScreen({
    super.key,
    this.recipientCount = 1,
  });

  @override
  State<SosConfirmScreen> createState() => _SosConfirmScreenState();
}

class _SosConfirmScreenState extends State<SosConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Start animation on next frame
    Future.microtask(() => _scaleController.forward());
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onBackToHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.dashboard,
      (route) => route.settings.name == AppRouter.dashboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated check icon
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppStateColors.successBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: AppColors.success,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Text(
                      'Đã gửi SOS',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 17,
                        ),
                        children: [
                          const TextSpan(text: 'Đã thông báo đến '),
                          TextSpan(
                            text: '${widget.recipientCount} người thân',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: '.\nHọ đang được kết nối để hỗ trợ bạn.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // SOS Info Card
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Vị trí của bạn',
                        value: 'Đã gửi cùng SOS',
                        color: AppColors.info,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Thời gian',
                        value: DateTime.now().toString().substring(0, 16),
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.notifications_active_outlined,
                        label: 'Trạng thái',
                        value: 'Đang chờ phản hồi',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Tips
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStateColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.strokeSoft),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColors.info,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Giữ bình tĩnh và ở yên một chỗ để người thân dễ tìm thấy bạn.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // CTA: Về trang chủ
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onBackToHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Về trang chủ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
