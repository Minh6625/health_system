import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';

class RangeFilterChips extends StatelessWidget {
  final String currentRange;
  final Function(String) onRangeSelected;

  const RangeFilterChips({
    super.key,
    required this.currentRange,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('7d', '7 ngày'),
          const SizedBox(width: 12),
          _buildChip('30d', '30 ngày'),
          const SizedBox(width: 12),
          _buildChip('90d', '90 ngày'),
        ],
      ),
    );
  }

  Widget _buildChip(String value, String label) {
    final isSelected = currentRange == value;
    return InkWell(
      onTap: () => onRangeSelected(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.strokeSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
