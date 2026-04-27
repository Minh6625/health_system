import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Thời gian đếm ngược mặc định (giây) trước khi tự động leo thang.
const int _kDefaultCountdownSeconds = 60;

/// Full-screen overlay hiển thị khi phát hiện chỉ số sức khỏe bất thường
/// (risk_high / risk_critical).
///
/// Hiển thị câu hỏi "Bạn có ổn không?" với hai lựa chọn:
/// - "Tôi ổn" → đóng overlay, ghi nhận người dùng đã xác nhận.
/// - "Tôi cần giúp đỡ" → leo thang thành SOS / liên hệ caregiver.
///
/// Nếu không phản hồi trong [countdownSeconds] giây → tự động leo thang.
class RiskAlertFullScreenOverlay extends StatefulWidget {
  /// Tiêu đề cảnh báo (vd: "⚠️ Cảnh báo sức khỏe").
  final String title;

  /// Nội dung mô tả chi tiết (vd: "Chỉ số sức khỏe ở mức cần lưu ý...").
  final String message;

  /// Mức độ risk: 'high' hoặc 'critical'.
  final String riskLevel;

  /// Alert type gốc từ backend (vd: 'risk_high', 'risk_critical').
  final String alertType;

  /// Notification ID từ backend (nếu có).
  final String? notificationId;

  /// Thời gian đếm ngược (giây) trước khi tự động leo thang.
  final int countdownSeconds;

  /// Callback khi người dùng chọn "Tôi ổn".
  final Future<void> Function() onConfirmOk;

  /// Callback khi người dùng chọn "Tôi cần giúp đỡ" hoặc hết thời gian.
  final Future<void> Function() onRequestHelp;

  /// Callback khi timeout kích hoạt leo thang riêng.
  final Future<void> Function() onTimeoutEscalated;

  /// Callback khi bấm đóng (dismiss).
  final Future<void> Function() onDismiss;

  const RiskAlertFullScreenOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.riskLevel,
    required this.alertType,
    this.notificationId,
    this.countdownSeconds = _kDefaultCountdownSeconds,
    required this.onConfirmOk,
    required this.onRequestHelp,
    required this.onTimeoutEscalated,
    required this.onDismiss,
  });

  @override
  State<RiskAlertFullScreenOverlay> createState() =>
      _RiskAlertFullScreenOverlayState();
}

class _RiskAlertFullScreenOverlayState extends State<RiskAlertFullScreenOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  late int _remainingSeconds;
  bool _isActionInProgress = false;

  bool get _isCritical => widget.riskLevel.toLowerCase() == 'critical';

  Color get _accentColor =>
      _isCritical ? AppColors.critical : AppColors.warning;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );

    _pulseController.repeat();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_isActionInProgress) {
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        unawaited(_handleAction(widget.onTimeoutEscalated));
      }
    });
  }

  Future<void> _handleAction(Future<void> Function() action) async {
    if (_isActionInProgress) {
      return;
    }

    setState(() {
      _isActionInProgress = true;
    });

    _countdownTimer?.cancel();
    _countdownTimer = null;

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('risk-alert-fullscreen-overlay'),
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blur background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.82)),
            ),
          ),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sectionGapXl,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pulse icon
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.28),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accentColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _isCritical
                                    ? Icons.warning_amber_rounded
                                    : Icons.monitor_heart_outlined,
                                color: _accentColor,
                                size: 44,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sectionGapXl),

                          // Title
                          Text(
                            key: const ValueKey('risk-alert-title'),
                            widget.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.bgSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.gapSm),

                          // Message
                          Text(
                            widget.message,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 28),

                          // "Bạn có ổn không?" question
                          const Text(
                            'Bạn có ổn không?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.bgSurface,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Countdown
                          Text(
                            key: const ValueKey('risk-alert-countdown'),
                            'Tự động yêu cầu hỗ trợ sau $_remainingSeconds giây',
                            style: TextStyle(
                              fontSize: 13,
                              color: _remainingSeconds <= 10
                                  ? AppColors.critical
                                  : Colors.white54,
                              fontWeight: _remainingSeconds <= 10
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Info card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                              AppSpacing.sectionGapLg,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppRadii.radiusLg,
                              ),
                              border: Border.all(
                                color: _accentColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: _accentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isCritical
                                        ? 'Chỉ số sức khỏe ở mức nguy hiểm. Nếu bạn không phản hồi, hệ thống sẽ tự động thông báo đến người thân.'
                                        : 'Chỉ số sức khỏe ở mức cần lưu ý. Vui lòng xác nhận tình trạng của bạn.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sectionGapXl),

                          // "Tôi ổn" button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey('risk-alert-safe-button'),
                              onPressed: _isActionInProgress
                                  ? null
                                  : () async {
                                      await _handleAction(widget.onConfirmOk);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: AppColors.bgSurface,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Tôi ổn',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // "Tôi cần giúp đỡ" button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey('risk-alert-help-button'),
                              onPressed: _isActionInProgress
                                  ? null
                                  : () async {
                                      await _handleAction(widget.onRequestHelp);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentColor,
                                foregroundColor: AppColors.bgSurface,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Tôi cần giúp đỡ',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.gapSm),

                          // Dismiss
                          TextButton(
                            key: const ValueKey('risk-alert-dismiss-button'),
                            onPressed: _isActionInProgress
                                ? null
                                : () async {
                                    await _handleAction(widget.onDismiss);
                                  },
                            child: const Text(
                              'Đóng',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
