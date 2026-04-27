import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../utils/notification_severity.dart';

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

/// Horizontally scrollable second filter row, allowing the user to narrow
/// the list down by alert kind (`Tất cả` / `Khẩn cấp` / `Sức khoẻ` / `Thuốc`
/// / `Hệ thống`).
class NotificationTypeFilterChips extends StatelessWidget {
  const NotificationTypeFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final NotificationTypeFilter selected;
  final ValueChanged<NotificationTypeFilter> onChanged;

  static const List<NotificationTypeFilter> _values =
      NotificationTypeFilter.values;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in _values) ...[
              _TypeFilterChip(
                label: notificationTypeFilterLabel(filter),
                filter: filter,
                selected: selected,
                onChanged: onChanged,
              ),
              if (filter != _values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.filter,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final NotificationTypeFilter filter;
  final NotificationTypeFilter selected;
  final ValueChanged<NotificationTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = filter == selected;
    final selectedColor = switch (filter) {
      NotificationTypeFilter.sos => AppColors.critical,
      NotificationTypeFilter.health => AppColors.warning,
      NotificationTypeFilter.medication => AppColors.success,
      NotificationTypeFilter.system => AppColors.textSecondary,
      NotificationTypeFilter.all => AppColors.info,
    };

    return Material(
      color: isSelected
          ? selectedColor.withValues(alpha: 0.14)
          : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        onTap: () => onChanged(filter),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? selectedColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
