import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Reusable row widget: [icon] + [label] + [value].
/// Font tối thiểu 16sp cho body text, đảm bảo Accessibility.
class MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? unit;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = const Color(0xFF48D6FF),
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Icon container – touch target ≥ 48dp via Row expansion
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.gapMd),
          // Label
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF90A6C3),
                fontSize: 18, // ≥ 18sp for better accessibility
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Value + unit
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(
                    color: Color(0xFF5B7FA6),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
