import 'package:flutter/material.dart';
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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Báo cáo & Nhật ký'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            labelColor: Colors.blue.shade700,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        {'time': '10:30 AM', 'title': 'Nhịp tim cao (110 BPM)', 'type': 'alert', 'color': Colors.orange.shade600, 'icon': Icons.warning_rounded, 'desc': 'Phát hiện nhịp tim đập nhanh khi nghỉ ngơi.'},
        {'time': '09:15 AM', 'title': 'Huyết áp bình thường', 'type': 'info', 'color': Colors.green.shade600, 'icon': Icons.favorite_rounded, 'desc': '120/80 mmHg - Chỉ số an toàn.'},
        {'time': '08:00 AM', 'title': 'Đo nhịp tim (82 BPM)', 'type': 'info', 'color': Colors.green.shade600, 'icon': Icons.monitor_heart, 'desc': 'Chỉ số trong vùng an toàn.'},
      ],
      'Hôm qua': [
        {'time': '08:45 PM', 'title': 'Mất kết nối cảm biến', 'type': 'error', 'color': Colors.grey.shade600, 'icon': Icons.bluetooth_disabled, 'desc': 'Đồng hồ mất tín hiệu trong 15 phút.'},
        {'time': '02:10 PM', 'title': 'SpO2 thấp (90%)', 'type': 'critical', 'color': Colors.red.shade600, 'icon': Icons.water_drop, 'desc': 'Nồng độ oxy xuống thấp, cần theo dõi.'},
      ],
    };

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final dateKey = groupedEvents.keys.elementAt(index);
        final eventsInDate = groupedEvents[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky-like Date Header
            Padding(
              padding: EdgeInsets.only(bottom: 16, top: index == 0 ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dateKey,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
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
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: ev['type'] == 'critical' ? Colors.red : (ev['color'] as Color),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: (ev['color'] as Color).withValues(alpha: 0.3),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                      if (!isLastEventInDate)
                        Container(
                          width: 2,
                          height: 70, // Connector line
                          color: Colors.grey.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Event Card
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ev['type'] == 'critical' ? Colors.red.shade200 : Colors.grey.shade100),
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (ev['color'] as Color).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(ev['icon'] as IconData, color: ev['color'] as Color, size: 24),
                          ),
                          const SizedBox(width: 16),
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
                                        style: TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      ev['time'] as String,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ev['desc'] as String,
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.3),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Selector (Mockup)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Hôm nay', isSelected: false),
                const SizedBox(width: 8),
                _FilterChip(label: '7 Ngày qua', isSelected: true),
                const SizedBox(width: 8),
                _FilterChip(label: '1 Tháng qua', isSelected: false),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
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
              _Legend(Colors.red.shade400, 'Nhịp tim')
            ],
          ),
          const SizedBox(height: 24),

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
              const SizedBox(width: 16),
              _Legend(Colors.teal.shade400, 'Tâm trương'),
            ],
          ),
          const SizedBox(height: 24),
          
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
          const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
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
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Trung bình',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        avgValue,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade700),
                      ),
                      const SizedBox(width: 2),
                      Text(unit, style: TextStyle(fontSize: 12, color: color.shade700)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Natural Language Insight (Soothes the user)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights, size: 20, color: color.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insightText,
                    style: TextStyle(fontSize: 14, color: color.shade900, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend (if multiple lines)
          if (legends.isNotEmpty) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: legends),
            const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade700 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
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
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
