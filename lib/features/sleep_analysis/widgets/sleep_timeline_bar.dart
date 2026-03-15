import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:intl/intl.dart';

/// Horizontal colored timeline bar visualizing sleep phases.
/// Shows Awake / Light / Deep / REM segments as flex blocks.
/// When [session.phases] is null, shows a single "no data" bar.
class SleepTimelineBar extends StatelessWidget {
  final SleepSession session;

  const SleepTimelineBar({super.key, required this.session});

  static const _awakeColor = Color(0xFFFFC400);
  static const _lightColor = Color(0xFF48A9D6);
  static const _deepColor = Color(0xFF3A5FCD);
  static const _remColor = Color(0xFF9C6ADE);
  static const _noDataColor = Color(0xFF2A3D5F);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x264B5E82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBar(),
          const SizedBox(height: 10),
          _buildTimeLabels(),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildBar() {
    final phases = session.phases;

    // No phase data → simple single-colour bar
    if (phases == null || phases.totalMinutes == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(height: 20, color: _noDataColor),
      );
    }

    final awake = session.awakeMinutes.toDouble();
    final light = phases.lightMinutes.toDouble();
    final deep = phases.deepMinutes.toDouble();
    final rem = phases.remMinutes.toDouble();
    final total = awake + light + deep + rem;

    if (total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(height: 20, color: _noDataColor),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 20,
        child: Row(
          children: [
            if (awake > 0)
              Flexible(
                flex: (awake / total * 1000).round(),
                child: Container(color: _awakeColor),
              ),
            if (light > 0)
              Flexible(
                flex: (light / total * 1000).round(),
                child: Container(color: _lightColor),
              ),
            if (deep > 0)
              Flexible(
                flex: (deep / total * 1000).round(),
                child: Container(color: _deepColor),
              ),
            if (rem > 0)
              Flexible(
                flex: (rem / total * 1000).round(),
                child: Container(color: _remColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeLabels() {
    final start = session.startTime;
    final end = session.endTime;
    final mid = start.add(end.difference(start) ~/ 2);
    final fmt = DateFormat('HH:mm');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _timeLabel(fmt.format(start)),
        _timeLabel(fmt.format(mid)),
        _timeLabel(fmt.format(end)),
      ],
    );
  }

  Widget _timeLabel(String t) => Text(
        t,
        style: const TextStyle(
          color: Color(0xFF5B7FA6),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _buildLegend() {
    final phases = session.phases;
    if (phases == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendDot(color: _awakeColor, label: 'Thức (${session.awakeText})'),
        _LegendDot(
            color: _lightColor,
            label: 'Ngủ nông (${_fmt(phases.lightMinutes)})'),
        _LegendDot(
            color: _deepColor, label: 'Ngủ sâu (${_fmt(phases.deepMinutes)})'),
        _LegendDot(
            color: _remColor, label: 'REM (${_fmt(phases.remMinutes)})'),
      ],
    );
  }

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF90A6C3),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
