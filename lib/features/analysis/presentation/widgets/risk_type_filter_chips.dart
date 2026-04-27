import 'package:flutter/material.dart';

/// Allow-list of risk types the chip row exposes. Mirrors
/// ``MonitoringService.RISK_HISTORY_TYPE_FILTERS`` on the backend
/// (Phase 4A-full slice 3b) plus an "All" pseudo-option that maps
/// to ``null`` (no server-side filter).
///
/// Order is the rendering order on the chip row.
const List<RiskTypeFilterOption> kRiskTypeFilters = [
  RiskTypeFilterOption(label: 'Tất cả', value: null),
  RiskTypeFilterOption(label: 'Sức khoẻ', value: 'general'),
  RiskTypeFilterOption(label: 'Giấc ngủ', value: 'sleep'),
  RiskTypeFilterOption(label: 'Té ngã', value: 'fall'),
];

/// One chip on the filter row.
class RiskTypeFilterOption {
  /// Display label (Vietnamese).
  final String label;

  /// Sent as ``risk_type=`` to the backend when this chip is selected.
  /// ``null`` means "no filter" — the chip is the "Tất cả" pseudo-option.
  final String? value;

  const RiskTypeFilterOption({required this.label, required this.value});
}

/// Horizontally-scrolling row of [ChoiceChip]s for selecting which
/// risk type the [RiskHistoryScreen] is showing.
///
/// Stateless — the screen owns the selection via
/// [RiskHistoryProvider.currentRiskType] and supplies it through
/// [selectedValue]. Tapping a chip calls [onChanged] with the new
/// value (``null`` for "All"); the screen forwards that to
/// [RiskHistoryProvider.changeRiskType].
///
/// Keeping the chip row stateless means it can be widget-tested
/// without booting the provider — the test just pumps the widget
/// with a stub callback.
class RiskTypeFilterChips extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String?> onChanged;
  final List<RiskTypeFilterOption> options;

  const RiskTypeFilterChips({
    super.key,
    required this.selectedValue,
    required this.onChanged,
    this.options = kRiskTypeFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final option in options) ...[
            ChoiceChip(
              label: Text(option.label),
              selected: option.value == selectedValue,
              onSelected: (isNowSelected) {
                if (!isNowSelected) {
                  // Re-tapping the active chip is a no-op (ChoiceChip
                  // tries to clear the selection). The screen always
                  // has SOMETHING selected (defaults to "All"), so
                  // ignore the deselect attempt.
                  return;
                }
                onChanged(option.value);
              },
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: option.value == selectedValue
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: option.value == selectedValue
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
