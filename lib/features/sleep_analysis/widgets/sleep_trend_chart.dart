import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:intl/intl.dart';

/// Bar chart hiển thị lịch sử 7 ngày với ngày cụ thể trên trục X.
/// Khi chạm vào cột, [onSessionTapped] gọi với session đó.
class SleepTrendChart extends StatefulWidget {
  final List<SleepSession> historyList;
  final ValueChanged<SleepSession>? onSessionTapped;

  /// Session đang được chọn để highlight cột tương ứng
  final DateTime? highlightedDate;

  const SleepTrendChart({
    super.key,
    required this.historyList,
    this.onSessionTapped,
    this.highlightedDate,
  });

  @override
  State<SleepTrendChart> createState() => _SleepTrendChartState();
}

class _SleepTrendChartState extends State<SleepTrendChart> {
  int _touchedIndex = -1;

  Color _barColor(int score) {
    if (score >= 70) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFFC400);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.historyList.isEmpty) return _buildEmptyPlaceholder();

    // Build sorted list of last 7 unique calendar days (oldest → newest)
    final slots = _buildChronologicalSlots();
    final highlightedIndex = widget.highlightedDate != null
        ? slots.indexWhere((s) => _isSameDay(s.date, widget.highlightedDate!))
        : -1;

    return SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF10233F),
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final slot = slots[group.x];
                    final dateStr = DateFormat('dd/MM').format(slot.date);
                    return BarTooltipItem(
                      '$dateStr\n${rod.toY.toInt()} điểm',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.spot == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex = response.spot!.touchedBarGroupIndex;
                      final session = slots[_touchedIndex].session;
                      if (session != null && widget.onSessionTapped != null) {
                        widget.onSessionTapped!(session);
                      }
                    }
                  });
                },
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 25,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Color(0xFF5B7FA6),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= slots.length) return const SizedBox();
                      final isActive =
                          i == _touchedIndex || i == highlightedIndex;
                      // Show "dd/MM" — e.g. "15/03"
                      final label = DateFormat('dd/MM').format(slots[i].date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFF4EDAFF)
                                : const Color(0xFF5B7FA6),
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0x1A4B5E82), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(slots.length, (i) {
                final slot = slots[i];
                final score = slot.score.toDouble();
                final isTouched = i == _touchedIndex || i == highlightedIndex;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: score,
                      color: isTouched
                          ? const Color(0xFF4EDAFF)
                          : _barColor(slot.score),
                      width: 20,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: const Color(0xFF111E33),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 100.ms)
        .slideY(begin: 0.08, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  /// Build chronological slots (oldest → newest) for the last 7 unique days
  List<_DaySlot> _buildChronologicalSlots() {
    // Group sessions by calendar day, keep best score per day
    final Map<String, _DaySlot> map = {};
    for (final session in widget.historyList) {
      final key = DateFormat('yyyy-MM-dd').format(session.sleepDate);
      final existing = map[key];
      if (existing == null || session.qualityScore > existing.score) {
        map[key] = _DaySlot(
          date: DateTime(
            session.sleepDate.year,
            session.sleepDate.month,
            session.sleepDate.day,
          ),
          score: session.qualityScore,
          session: session,
        );
      }
    }

    // Sort by date ascending so oldest is leftmost
    final slots = map.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    // Cap to 7 most recent days
    return slots.length > 7 ? slots.sublist(slots.length - 7) : slots;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildEmptyPlaceholder() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF111E33),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          'Chưa có dữ liệu xu hướng',
          style: TextStyle(color: Color(0xFF5B7FA6), fontSize: 14),
        ),
      ),
    );
  }
}

class _DaySlot {
  final DateTime date;
  final int score;
  final SleepSession? session;

  const _DaySlot({required this.date, required this.score, this.session});
}
