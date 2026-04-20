import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DashboardGreetingHeader extends StatefulWidget {
  final String displayName;
  final String? avatarUrl;
  final String latestUpdatedLabel;
  final bool hasUnreadNotifications;
  final int unreadNotificationCount;
  final VoidCallback onTapNotifications;

  const DashboardGreetingHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    required this.latestUpdatedLabel,
    this.hasUnreadNotifications = false,
    this.unreadNotificationCount = 0,
    required this.onTapNotifications,
  });

  @override
  State<DashboardGreetingHeader> createState() =>
      _DashboardGreetingHeaderState();
}

class _DashboardGreetingHeaderState extends State<DashboardGreetingHeader>
    with SingleTickerProviderStateMixin {
  static const Duration _ringInterval = Duration(seconds: 2);
  static const Duration _ringDuration = Duration(milliseconds: 650);

  late final AnimationController _ringController;
  late final Animation<double> _ringAnimation;
  Timer? _ringTimer;

  bool get _shouldRing {
    return widget.unreadNotificationCount > 0 || widget.hasUnreadNotifications;
  }

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: _ringDuration);
    _ringAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.22), weight: 12),
          TweenSequenceItem(tween: Tween(begin: -0.22, end: 0.20), weight: 22),
          TweenSequenceItem(tween: Tween(begin: 0.20, end: -0.16), weight: 22),
          TweenSequenceItem(tween: Tween(begin: -0.16, end: 0.10), weight: 22),
          TweenSequenceItem(tween: Tween(begin: 0.10, end: 0.0), weight: 22),
        ]).animate(
          CurvedAnimation(parent: _ringController, curve: Curves.easeInOut),
        );

    _syncRingLoop();
  }

  @override
  void didUpdateWidget(covariant DashboardGreetingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unreadNotificationCount != widget.unreadNotificationCount ||
        oldWidget.hasUnreadNotifications != widget.hasUnreadNotifications) {
      _syncRingLoop();
    }
  }

  void _syncRingLoop() {
    if (_shouldRing) {
      _startRingLoop();
      return;
    }

    _ringTimer?.cancel();
    _ringTimer = null;
    if (_ringController.isAnimating) {
      _ringController.stop();
    }
    _ringController.value = 0;
  }

  void _startRingLoop() {
    if (_ringTimer != null) {
      return;
    }

    _ringTimer = Timer.periodic(_ringInterval, (_) {
      if (!mounted || !_shouldRing) {
        return;
      }
      _ringController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = widget.unreadNotificationCount;
    final showBadge = unreadCount > 0 || widget.hasUnreadNotifications;
    final showUnreadNumber = unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sectionGapMd,
        bottom: AppSpacing.sectionGapMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.strokeSoft,
            backgroundImage: widget.avatarUrl != null
                ? NetworkImage(widget.avatarUrl!)
                : null,
            child: widget.avatarUrl == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSecondary,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào ${widget.displayName}',
                  style: AppTextStyles.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.gapXs),
                Text(
                  widget.latestUpdatedLabel,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: AnimatedBuilder(
                  animation: _ringAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _ringAnimation.value,
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                ),
                onPressed: widget.onTapNotifications,
              ),
              if (showBadge)
                Positioned(
                  right: -2,
                  top: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    constraints: BoxConstraints(
                      minWidth: showUnreadNumber ? 18 : 10,
                      minHeight: showUnreadNumber ? 18 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emergency,
                      borderRadius: AppRadii.pillRadius,
                      border: Border.all(color: AppColors.bgPrimary, width: 2),
                    ),
                    child: showUnreadNumber
                        ? Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
