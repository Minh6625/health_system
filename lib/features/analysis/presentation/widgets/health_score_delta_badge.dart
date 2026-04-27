import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';

/// Compact pill that surfaces a health-score delta with a directional icon
/// and a colored background. Signs follow the health-domain convention
/// (positive = improved, negative = worsened).
///
/// Used inside the trend cards on `RiskReportScreen` and
/// `RiskHistoryScreen` so users can immediately tell whether the latest
/// data is better, worse, or unchanged compared to the previous period.
class HealthScoreDeltaBadge extends StatelessWidget {
  const HealthScoreDeltaBadge({
    super.key,
    required this.delta,
    required this.comparedTo,
  });

  /// Signed health-score delta. Positive = improvement.
  final double delta;

  /// Suffix shown after the value, e.g. `'lần trước'` or `'kỳ trước'`.
  final String comparedTo;

  @override
  Widget build(BuildContext context) {
    final rounded = delta.roundToDouble();
    final isPositive = rounded > 0;
    final isNegative = rounded < 0;

    final Color color;
    final IconData icon;
    final String text;

    if (isPositive) {
      color = AppColors.success;
      icon = Icons.trending_up_rounded;
      text = '+${_formatDelta(delta)} so với $comparedTo';
    } else if (isNegative) {
      color = AppColors.critical;
      icon = Icons.trending_down_rounded;
      text = '${_formatDelta(delta)} so với $comparedTo';
    } else {
      color = AppColors.textSecondary;
      icon = Icons.trending_flat_rounded;
      text = 'Không đổi so với $comparedTo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDelta(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
