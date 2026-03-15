import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/widgets/quality_badge.dart';
import 'package:intl/intl.dart';

/// SleepHeroCard – redesigned with 3 sections:
///  1. WeeklyDatePicker  – horizontal 7-day strip + full-calendar button
///  2. ScoreAndDurationRow – quality ring, score, sleep time
///  3. AIAssessmentBubble – chibi doctor mascot + speech bubble
class SleepHeroCard extends StatelessWidget {
  final SleepSession? session;

  /// Called when user selects a day from the weekly strip
  final ValueChanged<DateTime>? onDateSelected;

  /// The currently selected date (highlights correct day in strip)
  final DateTime selectedDate;

  /// Called when user taps the full-calendar icon button
  final VoidCallback? onCalendarTap;

  const SleepHeroCard({
    super.key,
    required this.session,
    required this.selectedDate,
    this.onDateSelected,
    this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E2244), Color(0xFF091529)],
        ),
        border: Border.all(color: const Color(0x332C4367), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3048D6FF),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section 1: Weekly Date Picker ──────────────────────────────
          _WeeklyDatePicker(
            selectedDate: selectedDate,
            onDateSelected: onDateSelected,
            onCalendarTap: onCalendarTap,
          ),

          const Divider(color: Color(0x1A4B5E82), height: 1),

          // ── Section 2: Score & Duration ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: session == null
                ? _buildPlaceholder()
                : _ScoreAndDurationRow(session: session!),
          ),

          // ── Section 3: AI Assessment Bubble ────────────────────────────
          if (session != null) ...[
            const Divider(color: Color(0x1A4B5E82), height: 1),
            _AIAssessmentBubble(session: session!),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Chưa có dữ liệu giấc ngủ',
          style: TextStyle(color: Color(0xFF5B7FA6), fontSize: 16),
        ),
      ),
    );
  }
}

// ── Weekly Date Picker ────────────────────────────────────────────────────────

class _WeeklyDatePicker extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime>? onDateSelected;
  final VoidCallback? onCalendarTap;

  const _WeeklyDatePicker({
    required this.selectedDate,
    this.onDateSelected,
    this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          // 7-day strip
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((day) {
                final isSelected = _isSameDay(day, selectedDate);
                final isToday = _isSameDay(day, today);
                final dayLabel = _dayLabel(day.weekday);

                return GestureDetector(
                  onTap: () => onDateSelected?.call(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? const Color(0xFF153358)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF48D6FF)
                            : isToday
                                ? const Color(0x554EDAFF)
                                : const Color(0x223A5580),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabel,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF48D6FF)
                                : const Color(0xFF5B7FA6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? const Color(0xFF90A6C3)
                                    : const Color(0xFF4C6589),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(height: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF48D6FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 10),
          // Full calendar button
          GestureDetector(
            onTap: onCalendarTap,
            child: Container(
              width: 36,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x0F48D6FF),
                border: Border.all(
                    color: const Color(0x3348D6FF), width: 1),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF48D6FF),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(int weekday) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return labels[(weekday - 1).clamp(0, 6)];
  }
}

// ── Score + Duration Row ──────────────────────────────────────────────────────

class _ScoreAndDurationRow extends StatelessWidget {
  final SleepSession session;

  const _ScoreAndDurationRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: quality ring + score + badge below
        Column(
          children: [
            SizedBox(
              width: 116,
              height: 116,
              child: CustomPaint(
                painter: _QualityRingPainter(
                  value: session.qualityRatio,
                  color: session.qualityColor,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${session.qualityScore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    const Text(
                      'điểm',
                      style: TextStyle(
                          color: Color(0xFF90A6C3), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // QualityBadge centered below the ring
            QualityBadge(session: session),
          ],
        ),

        const SizedBox(width: 18),

        // Right column: sleep duration + info rows (bigger & clearer)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Sleep duration – main figure
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  session.sleepText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
              const Text(
                'Thời gian ngủ thực tế',
                style: TextStyle(
                  color: Color(0xFF7A96B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              // Info rows – larger font
              _InfoRow(
                icon: Icons.hotel_rounded,
                iconColor: const Color(0xFF48A9D6),
                label: 'Trên giường',
                value: session.inBedText,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.nightlight_round,
                iconColor: const Color(0xFFFFC400),
                label: 'Thức giấc',
                value: '${session.wakeCount} lần',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.percent_rounded,
                iconColor: const Color(0xFF4CAF50),
                label: 'Hiệu quả',
                value:
                    '${(session.efficiencyRatio * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = const Color(0xFF5B7FA6),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A96B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFCCDEF5),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── AI Assessment Bubble ──────────────────────────────────────────────────────

class _AIAssessmentBubble extends StatelessWidget {
  final SleepSession session;

  const _AIAssessmentBubble({required this.session});

  String _buildMessage(SleepSession s) {
    final wakeText = s.wakeCount == 0
        ? 'Bác ngủ ngon, không thức giấc lần nào cả!'
        : s.wakeCount == 1
            ? 'Bác thức giấc 1 lần đêm qua, khá ổn đấy!'
            : 'Bác đã thức dậy ${s.wakeCount} lần đêm qua.';

    switch (s.qualityLabel.toUpperCase()) {
      case 'GOOD':
        return '$wakeText Hiệu quả ngủ ${(s.efficiencyRatio * 100).toStringAsFixed(0)}% – tuyệt vời! Cố gắng duy trì nhé bác! 🌙';
      case 'POOR':
        return '$wakeText Giấc ngủ ${s.sleepText} hơi ngắn. Bác nên đi ngủ sớm hơn và tránh dùng điện thoại trước khi ngủ nhé! 💙';
      case 'AVERAGE':
      default:
        return '$wakeText Giấc ngủ ${s.sleepText} chấp nhận được. Bác thử đi ngủ đúng giờ mỗi đêm để cải thiện thêm nhé! 😊';
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _buildMessage(session);
    final dateStr =
        DateFormat('dd/MM/yyyy').format(session.endTime);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mascot
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF152B4A),
                  border: Border.all(color: const Color(0x3348D6FF), width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/doctor_mascot.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF48D6FF),
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'AI Bác sĩ',
                style: TextStyle(
                  color: Color(0xFF48D6FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Speech bubble
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152B4A),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                    ),
                    border: Border.all(
                        color: const Color(0x3348D6FF), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              color: Color(0xFF48D6FF), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Phân tích ngày $dateStr',
                            style: const TextStyle(
                              color: Color(0xFF48D6FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFB8CAE3),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quality Ring Painter ──────────────────────────────────────────────────────

class _QualityRingPainter extends CustomPainter {
  final double value;
  final Color color;

  const _QualityRingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1E3352)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      6.28318 * value.clamp(0, 1),
      false,
      Paint()
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0.5), color],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _QualityRingPainter old) =>
      old.value != value || old.color != color;
}
