import 'package:flutter/material.dart';
import '../models/vital_signs.dart';

class VitalCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final VitalStatus status;
  final VoidCallback? onTap;

  const VitalCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
    this.onTap,
  });

  Color _getBackgroundColor() {
    switch (status) {
      case VitalStatus.normal:
        return Colors.green.shade50;
      case VitalStatus.warning:
        return Colors.orange.shade50;
      case VitalStatus.critical:
        return Colors.red.shade50;
      case VitalStatus.unknown:
        return Colors.grey.shade50;
    }
  }

  Color _getIconColor() {
    switch (status) {
      case VitalStatus.normal:
        return Colors.green.shade700;
      case VitalStatus.warning:
        return Colors.orange.shade700;
      case VitalStatus.critical:
        return Colors.red.shade700;
      case VitalStatus.unknown:
        return Colors.grey.shade700;
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case VitalStatus.normal:
        return Colors.green.shade200;
      case VitalStatus.warning:
        return Colors.orange.shade300;
      case VitalStatus.critical:
        return Colors.red.shade300;
      case VitalStatus.unknown:
        return Colors.grey.shade300;
    }
  }

  String _getStatusText() {
    switch (status) {
      case VitalStatus.normal:
        return 'Bình thường';
      case VitalStatus.warning:
        return 'Cảnh báo';
      case VitalStatus.critical:
        return 'Nguy hiểm';
      case VitalStatus.unknown:
        return 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBorderColor(),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getIconColor().withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: _getIconColor(),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getIconColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getIconColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _getIconColor(),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
