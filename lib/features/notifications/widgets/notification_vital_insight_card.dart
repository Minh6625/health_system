import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../utils/notification_vital_insight.dart';

/// Color palette for the colored vital-insight card (green / orange / red).
({Color bg, Color border, Color accent}) notificationVitalPalette(
  NotificationVitalState state,
) {
  return switch (state) {
    NotificationVitalState.normal => (
      bg: AppStateColors.successBg,
      border: const Color(0xFFCDE9D7),
      accent: AppColors.success,
    ),
    NotificationVitalState.warning => (
      bg: AppStateColors.warningBg,
      border: const Color(0xFFF8CF9B),
      accent: AppColors.warning,
    ),
    NotificationVitalState.critical => (
      bg: AppStateColors.criticalBg,
      border: const Color(0xFFF4B6BF),
      accent: AppColors.critical,
    ),
  };
}

/// Card showing the dominant vital reading (heart rate / SpO2 / blood
/// pressure / temperature) attached to a notification, with status-aware
/// colour palette.
class NotificationVitalInsightCard extends StatelessWidget {
  const NotificationVitalInsightCard({super.key, required this.insight});

  final NotificationVitalInsight insight;

  @override
  Widget build(BuildContext context) {
    final palette = notificationVitalPalette(insight.state);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: palette.border, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(insight.icon, size: 18, color: palette.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.metricLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.valueText,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.statusLabel,
            style: TextStyle(
              fontSize: 12,
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
