import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Full-screen modal overlay hiển thị khi có SOS active khi vào tab Theo dõi.
class FamilySOSFullScreenOverlay extends StatefulWidget {
  /// Danh sách profiles đang có SOS (có thể nhiều hơn 1).
  final List<FamilyProfileSnapshot> sosProfiles;

  /// Callback khi bấm "Xem ngay" — truyền sosId (KHÔNG phải profileId)
  final void Function(String sosId) onViewDetail;
  final VoidCallback onDismiss;

  const FamilySOSFullScreenOverlay({
    super.key,
    required this.sosProfiles,
    required this.onViewDetail,
    required this.onDismiss,
  });

  @override
  State<FamilySOSFullScreenOverlay> createState() =>
      _FamilySOSFullScreenOverlayState();
}

class _FamilySOSFullScreenOverlayState
    extends State<FamilySOSFullScreenOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: -2), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -2, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _shakeController.repeat();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.sosProfiles.first;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blur background layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.82),
              ),
            ),
          ),

          // Content layer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sectionGapXl,
                vertical: 32,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon cảnh báo với shake animation
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.emergency,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.emergency,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGapXl),
                  // Tiêu đề
                  const Text(
                    'Yêu cầu SOS!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.bgSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapSm),
                  Text(
                    widget.sosProfiles.length == 1
                        ? '${primary.name} đang cần hỗ trợ khẩn cấp'
                        : '${widget.sosProfiles.length} người đang cần hỗ trợ khẩn cấp',
                    style:
                        const TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Card thông tin người SOS
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sectionGapLg),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius:
                          BorderRadius.circular(AppRadii.radiusLg),
                      border: Border.all(
                        color:
                            AppColors.emergency.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Column(
                      children: widget.sosProfiles
                          .map((p) => _buildProfileRow(p))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGapXl),
                  // CTA "Xem ngay"
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          widget.onViewDetail(primary.sosId ?? primary.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emergency,
                        foregroundColor: AppColors.bgSurface,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Xem ngay',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGapSm),
                  // Nút đóng
                  TextButton(
                    onPressed: widget.onDismiss,
                    child: const Text(
                      'Đóng',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(FamilyProfileSnapshot p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.gapSm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.emergency.withValues(alpha: 0.35),
            child: Text(
              p.name.isNotEmpty ? p.name[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.emergency,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.bgSurface,
                  ),
                ),
                Text(
                  p.relation,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        ],
      ),
    );
  }
}
