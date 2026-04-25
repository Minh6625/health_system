import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_radii.dart';

/// Small pill-shaped label used both in the list (alert type, severity, "Mới")
/// and in the detail header.
class NotificationInfoChip extends StatelessWidget {
  const NotificationInfoChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: AppRadii.pillRadius,
        color: color,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
