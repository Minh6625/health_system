import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
import '../widgets/mini_line_chart.dart';

/// Macro-view screen showing a consolidated report of all health events and trends.
/// Follows Plan §2.2: Combines History and Stats into a single screen with Tabs.
class HealthReportScreen extends StatelessWidget {
  const HealthReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: const Text('Báo cáo & Nhật ký'),
          backgroundColor: AppColors.bgSurface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            labelColor: AppColors.brandPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.brandPrimary,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Nhật ký'),
              Tab(text: 'Thống kê'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TimelineTab(),
            _TrendsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Timeline Tab ────────────────────────────────────────────────────────────
class _TimelineTab extends StatelessWidget {
  const _TimelineTab();

  @override
  Widget build(BuildContext context) {
    // New design: Group by Date
    final Map<String, List<Map<String, dynamic>>> groupedEvents = {
      'Hôm nay': [
        {'time': '10:30 AM', 'title': 'Nhịp tim cao (110 BPM)', 'type': 'alert', 'color': AppColors.warning, 'icon': Icons.warning_rounded, 'desc': 'Phát hiện nhịp tim đập nhanh khi nghỉ ngơi.'},
        {'time': '09:15 AM', 'title': 'Huyết áp bình thường', 'type': 'info', 'color': AppColors.success, 'icon': Icons.favorite_rounded, 'desc': '120/80 mmHg - Chỉ số an toàn.'},
        {'time': '08:00 AM', 'title': 'Đo nhịp tim (82 BPM)', 'type': 'info', 'color': AppColors.success, 'icon': Icons.monitor_heart, 'desc': 'Chỉ số trong vùng an toàn.'},
      ],
      'Hôm qua': [
        {'time': '08:45 PM', 'title': 'Mất kết nối cảm biến', 'type': 'error', 'color': AppColors.textSecondary, 'icon': Icons.bluetooth_disabled, 'desc': 'Đồng hồ mất tín hiệu trong 15 phút.'},
        {'time': '02:10 PM', 'title': 'SpO2 thấp (90%)', 'type': 'critical', 'color': AppColors.critical, 'icon': Icons.water_drop, 'desc': 'Nồng độ oxy xuống thấp, cần theo dõi.'},
      ],
    };

    return ListView.builder(
      padding: AppSpacing.screenHorizontalPadding.copyWith(top: AppSpacing.sectionGapMd, bottom: AppSpacing.sectionGapMd),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final dateKey = groupedEvents.keys.elementAt(index);
        final eventsInDate = groupedEvents[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky-like Date Header
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sectionGapMd, top: index == 0 ? 0 : AppSpacing.sectionGapMd),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapMd, vertical: 6),
                decoration: BoxDecoration(
                  color: AppStateColors.infoBg,
                  borderRadius: AppRadii.cardRadius,
                ),
                child: Text(
                  dateKey,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
            
            // Events for this date
            ...eventsInDate.asMap().entries.map((entry) {
              final evIndex = entry.key;
              final ev = entry.value;
              final isLastEventInDate = evIndex == eventsInDate.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline line + dot
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: AppSpacing.gapXs),
                        decoration: BoxDecoration(
                          color: ev['type'] == 'critical' ? AppColors.critical : (ev['color'] as Color),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bgSurface, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: (ev['color'] as Color).withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      if (!isLastEventInDate)
                        Container(
                          width: 2,
                          height: 70, // Connector line
                          color: AppColors.strokeSoft,
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sectionGapMd),
                  
                  // Event Card
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sectionGapLg),
                      padding: AppSpacing.cardPadding,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(
                          color: ev['type'] == 'critical'
                              ? AppColors.critical.withValues(alpha: 0.3)
                              : AppColors.strokeSoft,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.gapSm),
                            decoration: BoxDecoration(
                              color: (ev['color'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                            ),
                            child: Icon(ev['icon'] as IconData, color: ev['color'] as Color, size: 24),
                          ),
                          const SizedBox(width: AppSpacing.sectionGapMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ev['title'] as String,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ev['time'] as String,
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ev['desc'] as String,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Trends Tab ──────────────────────────────────────────────────────────────
class _TrendsTab extends StatelessWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenHorizontalPadding.copyWith(top: AppSpacing.sectionGapMd, bottom: AppSpacing.sectionGapMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Selector (Mockup)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Hôm nay', isSelected: false),
                const SizedBox(width: AppSpacing.gapSm),
                _FilterChip(label: '7 Ngày qua', isSelected: true),
                const SizedBox(width: AppSpacing.gapSm),
                _FilterChip(label: '1 Tháng qua', isSelected: false),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGapXl),
          
          // Thống kê 1: Nhịp tim (Tách riêng để tránh lộn xộn trục Y)
          _buildMetricSection(
            context,
            title: 'Biến động Nhịp tim (BPM)',
            insightText: 'Nhịp tim trung bình trong tuần là 78 bpm, duy trì vùng an toàn.',
            avgValue: '78',
            unit: 'bpm',
            color: Colors.red,
            chartHeight: 120,
            chartData: const [[72, 75, 78, 85, 82, 76, 74, 72]],
            chartColors: [Colors.red.shade400],
            xLabels: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN', 'HN'],
            legends: [
              _Legend(Colors.red.shade400, 'Nhịp tim'),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGapXl),

          // Thống kê 2: Huyết áp (Chỉ chứa Tâm thu & Tâm trương vì cùng chung đơn vị mmHg)
          _buildMetricSection(
            context,
            title: 'Huyết áp (mmHg)',
            insightText: 'Huyết áp có dấu hiệu tăng nhẹ vào buổi sáng, cần chú ý theo dõi.',
            avgValue: '124 / 82',
            unit: 'mmHg',
            color: Colors.purple,
            chartHeight: 140,
            chartData: const [
              [120, 122, 118, 125, 130, 128, 120, 118], // Sys
              [80, 82, 78, 85, 88, 85, 80, 78], // Dia
            ],
            chartColors: [Colors.purple.shade400, Colors.teal.shade400],
            xLabels: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN', 'HN'],
            legends: [
              _Legend(Colors.purple.shade400, 'Tâm thu'),
              const SizedBox(width: AppSpacing.sectionGapMd),
              _Legend(Colors.teal.shade400, 'Tâm trương'),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGapXl),
          
          // Thống kê 3: SpO2
          _buildMetricSection(
            context,
            title: 'Khí máu (SpO2)',
            insightText: 'Oxy trong máu luôn ổn định trên 96%.',
            avgValue: '98',
            unit: '%',
            color: Colors.blue,
            chartHeight: 100,
            chartData: const [[98, 97, 98, 99, 98, 97, 96, 98]],
            chartColors: [Colors.blue.shade400],
            xLabels: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN', 'HN'],
            legends: [], // 1 line, no legend needed
          ),
          const SizedBox(height: AppSpacing.sectionGapXl),
        ],
      ),
    );
  }

  Widget _buildMetricSection(
    BuildContext context, {
    required String title,
    required String insightText,
    required String avgValue,
    required String unit,
    required MaterialColor color,
    required double chartHeight,
    required List<List<double>> chartData,
    required List<Color> chartColors,
    required List<String> xLabels,
    required List<Widget> legends,
  }) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Average Value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.sectionTitle,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Trung bình',
                    style: AppTextStyles.caption,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        avgValue,
                        style: AppTextStyles.vitalValue.copyWith(color: color.shade700),
                      ),
                      const SizedBox(width: 2),
                      Text(unit, style: AppTextStyles.caption.copyWith(color: color.shade700)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          
          // Natural Language Insight (Soothes the user)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapMd, vertical: 10),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(AppRadii.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights, size: 20, color: color.shade700),
                const SizedBox(width: AppSpacing.gapSm),
                Expanded(
                  child: Text(
                    insightText,
                    style: AppTextStyles.caption.copyWith(
                      color: color.shade900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGapMd),

          // Legend (if multiple lines)
          if (legends.isNotEmpty) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: legends),
            const SizedBox(height: AppSpacing.gapMd),
          ],

          // The Chart itself
          MiniLineChart(
            height: chartHeight,
            linesData: chartData,
            lineColors: chartColors,
            xLabels: xLabels,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  const _FilterChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sectionGapMd, vertical: AppSpacing.gapSm),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.brandPrimary : AppColors.bgSurface,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: isSelected ? AppColors.brandPrimary : AppColors.strokeSoft),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: isSelected ? AppColors.bgSurface : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}

// Removed _SummaryCard because it was replaced by the _buildMetricSection with natural language.

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 4, color: color),
        const SizedBox(width: AppSpacing.gapXs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
