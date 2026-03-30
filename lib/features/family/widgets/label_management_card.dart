import 'package:flutter/material.dart';

class LabelManagementCard extends StatelessWidget {
  final String title;
  final String currentLabel;
  final VoidCallback onTapChange;
  final bool isUpdating;

  const LabelManagementCard({
    super.key,
    required this.title,
    required this.currentLabel,
    required this.onTapChange,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isUpdating ? null : onTapChange,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF12304A),
                    ),
                  ),
                ),
                if (isUpdating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF5B7288),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    currentLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5B7288),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Thay đổi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F80ED),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
