import 'package:flutter/material.dart';

import 'package:healthguard/features/family/models/recent_alert_item.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Single row inside [AlertHistorySection].
///
/// Visual rules:
///   * Icon shape comes from [RecentAlertType] (sos / fall / heart / sleep …).
///   * Foreground accent comes from [RecentAlertSeverity] so a critical
///     vital_abnormal still reads "red", not "neutral".
///   * Resolved alerts dim to ``opacity 0.65`` and gain an "Đã xử lý" chip;
///     keeping them on-list is intentional so caregivers see context, not
///     just a snapshot of currently-open issues.
class AlertHistoryItem extends StatelessWidget {
  const AlertHistoryItem({
    super.key,
    required this.alert,
    this.onTap,
  });

  final RecentAlertItem alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(alert.severity);
    final iconData = _iconForType(alert.alertType);

    final card = Container(
      margin: EdgeInsets.only(bottom: AppSpacing.gapSm),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadii.radiusMd),
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.gapLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeadingIcon(icon: iconData, color: accent),
                SizedBox(width: AppSpacing.gapSm),
                Expanded(child: _Body(alert: alert, accent: accent)),
              ],
            ),
          ),
        ),
      ),
    );

    if (alert.isResolved) {
      // Resolved rows fade — still tappable, still readable, just clearly
      // out of "needs attention" status.
      return Opacity(opacity: 0.65, child: card);
    }
    return card;
  }

  static Color _accentColor(RecentAlertSeverity severity) {
    switch (severity) {
      case RecentAlertSeverity.critical:
        return AppColors.emergency;
      case RecentAlertSeverity.high:
        return AppColors.critical;
      case RecentAlertSeverity.medium:
        return AppColors.warning;
      case RecentAlertSeverity.low:
        return AppColors.textSecondary;
    }
  }

  static IconData _iconForType(RecentAlertType type) {
    switch (type) {
      case RecentAlertType.sosTriggered:
        return Icons.sos_rounded;
      case RecentAlertType.fallDetected:
        return Icons.personal_injury_rounded;
      case RecentAlertType.riskCritical:
      case RecentAlertType.riskHigh:
        return Icons.monitor_heart_rounded;
      case RecentAlertType.vitalAbnormal:
        return Icons.favorite_rounded;
      case RecentAlertType.sleepAnomaly:
        return Icons.bedtime_rounded;
      case RecentAlertType.unknown:
        return Icons.notifications_active_rounded;
    }
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.alert, required this.accent});

  final RecentAlertItem alert;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatRelative(alert.occurredAt),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (alert.message != null && alert.message!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            alert.message!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            _SeverityChip(severity: alert.severity, color: accent),
            if (alert.isResolved) ...[
              const SizedBox(width: 6),
              const _ResolvedChip(),
            ],
          ],
        ),
      ],
    );
  }

  /// "Vừa xong / Xx phút trước / Xx giờ trước / N ngày trước" — local time.
  ///
  /// Keeping this self-contained avoids pulling ``timeago`` (extra dep) for
  /// six lines of formatting; the section only renders 10 items at most so
  /// performance is a non-issue.
  static String _formatRelative(DateTime occurredAtUtc) {
    final now = DateTime.now();
    final diff = now.difference(occurredAtUtc.toLocal());
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    final d = occurredAtUtc.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity, required this.color});

  final RecentAlertSeverity severity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: Text(
        _label(severity),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static String _label(RecentAlertSeverity severity) {
    switch (severity) {
      case RecentAlertSeverity.critical:
        return 'Khẩn cấp';
      case RecentAlertSeverity.high:
        return 'Cao';
      case RecentAlertSeverity.medium:
        return 'Trung bình';
      case RecentAlertSeverity.low:
        return 'Thấp';
    }
  }
}

class _ResolvedChip extends StatelessWidget {
  const _ResolvedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppStateColors.successBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      ),
      child: const Text(
        'Đã xử lý',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.success,
        ),
      ),
    );
  }
}
