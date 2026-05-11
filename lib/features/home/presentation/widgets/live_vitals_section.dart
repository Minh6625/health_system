import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import 'vital_metric_card.dart';

class LiveVitalsSection extends StatelessWidget {
  final List<VitalMetricItem> items;
  final VoidCallback? onTapHistory;

  const LiveVitalsSection({super.key, required this.items, this.onTapHistory});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Logic to switch to single column if font scale is too high or screen too narrow
        final useSingleColumn =
            MediaQuery.textScalerOf(context).scale(1) >= 1.4 ||
            constraints.maxWidth < 360;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chỉ số hôm nay', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.sectionGapMd),
            if (useSingleColumn)
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.gapMd),
                  child: VitalMetricCard(item: item),
                ),
              )
            else
              // Manual 2-column grid to avoid unbounded height / assertion errors
              // when used inside CustomScrollView/SliverList
              ..._buildGridRows(items, AppSpacing.gapMd),
          ],
        );
      },
    );
  }

  List<Widget> _buildGridRows(List<VitalMetricItem> items, double spacing) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < items.length ? spacing : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: VitalMetricCard(item: items[i])),
              SizedBox(width: spacing),
              Expanded(
                child: i + 1 < items.length
                    ? VitalMetricCard(item: items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}
