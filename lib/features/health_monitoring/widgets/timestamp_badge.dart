import 'package:flutter/material.dart';
import '../models/vital_signs.dart';

/// A badge that shows when data was last updated.
/// Smoothly transitions color + text between "Fresh" and "Stale" states
/// using [AnimatedSwitcher] and [AnimatedContainer] whenever [vitals] changes.
class TimestampBadge extends StatelessWidget {
  final VitalSigns vitals;

  const TimestampBadge({super.key, required this.vitals});

  String _getFullLabel(bool isStale) {
    final timeStr = _formatTime(vitals.timestamp);
    if (isStale) return 'Mất kết nối từ $timeStr';
    
    final timeDiff = DateTime.now().difference(vitals.timestamp);
    if (timeDiff.inSeconds < 60) return 'Vừa cập nhật lúc $timeStr';
    if (timeDiff.inMinutes < 60) return 'Cập nhật ${timeDiff.inMinutes} phút trước ($timeStr)';
    return 'Cập nhật lúc $timeStr';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isStale = vitals.isStale;
    final bgColor = isStale ? Colors.orange.shade50 : Colors.blue.shade50;
    final borderColor =
        isStale ? Colors.orange.shade200 : Colors.blue.shade200;
    final iconColor =
        isStale ? Colors.orange.shade700 : Colors.blue.shade700;
    final textColor =
        isStale ? Colors.orange.shade900 : Colors.blue.shade900;
    final icon = isStale ? Icons.warning_amber : Icons.check_circle;
    final label = _getFullLabel(isStale);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(icon, key: ValueKey(isStale), color: iconColor, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                label,
                key: ValueKey(label),
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (isStale)
            Icon(Icons.sync_problem, color: Colors.orange.shade700, size: 20),
        ],
      ),
    );
  }
}
