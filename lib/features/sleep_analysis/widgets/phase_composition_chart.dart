import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';

/// Donut chart hiển thị tỉ lệ các giai đoạn giấc ngủ: Light / Deep / REM.
/// Ẩn hoàn toàn khi [session.phases] == null.
class PhaseCompositionChart extends StatefulWidget {
  final SleepSession session;

  const PhaseCompositionChart({super.key, required this.session});

  @override
  State<PhaseCompositionChart> createState() => _PhaseCompositionChartState();
}

class _PhaseCompositionChartState extends State<PhaseCompositionChart> {
  int _touchedIndex = -1;

  static const _lightColor = Color(0xFF48A9D6);
  static const _deepColor = Color(0xFF3A5FCD);
  static const _remColor = Color(0xFF9C6ADE);

  @override
  Widget build(BuildContext context) {
    final phases = widget.session.phases;

    // Per PLAN: ẩn widget khi phases null, không crash
    if (phases == null) return const SizedBox.shrink();

    final total = phases.totalMinutes;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            children: [
              // Chart
              Expanded(
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex = response
                                .touchedSection!.touchedSectionIndex;
                          }
                        });
                      },
                    ),
                    centerSpaceRadius: 50,
                    sectionsSpace: 3,
                    sections: _buildSections(phases),
                  ),
                ),
              ),

              // Legend
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(
                    color: _lightColor,
                    label: 'Ngủ nông',
                    minutes: phases.lightMinutes,
                  ),
                  const SizedBox(height: 10),
                  _LegendItem(
                    color: _deepColor,
                    label: 'Ngủ sâu',
                    minutes: phases.deepMinutes,
                  ),
                  const SizedBox(height: 10),
                  _LegendItem(
                    color: _remColor,
                    label: 'REM',
                    minutes: phases.remMinutes,
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildSections(SleepPhasesDTO phases) {
    final total = phases.totalMinutes.toDouble();
    final sections = [
      (label: 'Nông', val: phases.lightMinutes.toDouble(), color: _lightColor),
      (label: 'Sâu', val: phases.deepMinutes.toDouble(), color: _deepColor),
      (label: 'REM', val: phases.remMinutes.toDouble(), color: _remColor),
    ];

    return List.generate(sections.length, (i) {
      final s = sections[i];
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 52.0 : 44.0;
      final pct = total > 0 ? (s.val / total * 100).toStringAsFixed(0) : '0';

      return PieChartSectionData(
        value: s.val,
        color: s.color,
        radius: radius,
        title: '$pct%',
        titleStyle: TextStyle(
          color: Colors.white,
          fontSize: isTouched ? 14 : 12,
          fontWeight: FontWeight.w700,
        ),
        badgeWidget: null,
      );
    });
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int minutes;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF90A6C3), fontSize: 12),
            ),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
