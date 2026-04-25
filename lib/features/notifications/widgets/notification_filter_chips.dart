import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';

/// Filter values exposed to the parent screen.
enum NotificationFilter { all, unread, read }

/// Three-segment filter row (`Tất cả` / `Chưa đọc` / `Đã đọc`) used at the
/// top of the notifications list.
class NotificationFilterChips extends StatelessWidget {
  const NotificationFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'Tất cả',
              filter: NotificationFilter.all,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: 'Chưa đọc',
              filter: NotificationFilter.unread,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: 'Đã đọc',
              filter: NotificationFilter.read,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.filter,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final NotificationFilter filter;
  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = filter == selected;
    final selectedColor = switch (filter) {
      NotificationFilter.unread => AppColors.critical,
      NotificationFilter.read => AppColors.success,
      NotificationFilter.all => AppColors.info,
    };

    return Material(
      color: isSelected
          ? selectedColor.withValues(alpha: 0.12)
          : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        onTap: () => onChanged(filter),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.radiusSm),
            border: Border.all(
              color: isSelected ? selectedColor : AppColors.strokeSoft,
              width: isSelected ? 1.4 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? selectedColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
