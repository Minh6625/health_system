import 'package:flutter/material.dart';

import 'package:healthguard/features/fall/models/fall_event.dart';

/// Compact chip rendering of [FallEventStatus] with status-coded
/// colour + Vietnamese label.
///
/// Pulled out of `fall_history_screen.dart` so the same chip can be
/// reused on the alert screen header + the home-screen banner.
class FallStatusChip extends StatelessWidget {
  final FallEventStatus status;

  const FallStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.foreground.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(palette.icon, size: 14, color: palette.foreground),
          const SizedBox(width: 6),
          Text(
            _labelFor(status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _labelFor(FallEventStatus status) {
    switch (status) {
      case FallEventStatus.detected:
        return 'Phát hiện ngã';
      case FallEventStatus.dismissed:
        return 'Đã bỏ qua';
      case FallEventStatus.confirmed:
        return 'Cần giúp đỡ';
      case FallEventStatus.escalated:
        return 'Đã báo SOS';
      case FallEventStatus.unknown:
        return 'Không xác định';
    }
  }

  static _Palette _palette(ThemeData theme, FallEventStatus status) {
    final cs = theme.colorScheme;
    switch (status) {
      case FallEventStatus.detected:
      case FallEventStatus.unknown:
        return _Palette(
          background: cs.errorContainer,
          foreground: cs.onErrorContainer,
          icon: Icons.warning_amber_rounded,
        );
      case FallEventStatus.dismissed:
        return _Palette(
          background: cs.surfaceContainerHighest,
          foreground: cs.onSurfaceVariant,
          icon: Icons.check_circle_outline_rounded,
        );
      case FallEventStatus.confirmed:
        return _Palette(
          background: cs.tertiaryContainer,
          foreground: cs.onTertiaryContainer,
          icon: Icons.support_agent_rounded,
        );
      case FallEventStatus.escalated:
        return _Palette(
          background: cs.errorContainer,
          foreground: cs.onErrorContainer,
          icon: Icons.emergency_rounded,
        );
    }
  }
}

class _Palette {
  final Color background;
  final Color foreground;
  final IconData icon;
  const _Palette({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
