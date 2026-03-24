import 'package:flutter/material.dart';

enum AddContactMode { scan, myCode, searchPhone }

class ModeSegmentedControl extends StatelessWidget {
  final AddContactMode currentMode;
  final ValueChanged<AddContactMode> onModeChanged;

  const ModeSegmentedControl({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegment(
              title: 'Quét mã',
              icon: Icons.qr_code_scanner,
              isSelected: currentMode == AddContactMode.scan,
              onTap: () => onModeChanged(AddContactMode.scan),
            ),
          ),
          Expanded(
            child: _buildSegment(
              title: 'Mã của tôi',
              icon: Icons.qr_code,
              isSelected: currentMode == AddContactMode.myCode,
              onTap: () => onModeChanged(AddContactMode.myCode),
            ),
          ),
          Expanded(
            child: _buildSegment(
              title: 'SĐT',
              icon: Icons.search,
              isSelected: currentMode == AddContactMode.searchPhone,
              onTap: () => onModeChanged(AddContactMode.searchPhone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF12304A)
                  : const Color(0xFF5B7288),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF12304A)
                    : const Color(0xFF5B7288),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
