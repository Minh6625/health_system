import 'package:flutter/material.dart';

class PermissionToggleCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  const PermissionToggleCard({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    this.isSaving = false,
    required this.onChanged,
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
          borderRadius: BorderRadius.circular(16),
          onTap: isSaving ? null : () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF12304A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5B7288),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (isSaving)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: Padding(
                      padding: EdgeInsets.all(6.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2F80ED),
                        ),
                      ),
                    ),
                  )
                else
                  Switch(
                    value: value,
                    onChanged: (val) => onChanged(val),
                    activeThumbColor: const Color(0xFF2F80ED),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
