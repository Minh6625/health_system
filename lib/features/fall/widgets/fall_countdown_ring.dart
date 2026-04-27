import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 30-second circular countdown ring used by [FallAlertScreen].
///
/// Drives a [Ticker]-equivalent via a periodic [Stream] (avoids
/// requiring `SingleTickerProviderStateMixin` in the parent) and
/// fires [onElapsed] exactly once when the timer reaches zero.
///
/// Test hook: passing a custom [tickInterval] lets pump-widget tests
/// race the countdown forward in a single second of test time
/// without rebuilding the layout 30+ times.
class FallCountdownRing extends StatefulWidget {
  /// Total countdown length. Defaults to 30 seconds (matches the
  /// auto-SOS escalation window in the backend's fall workflow).
  final Duration duration;

  /// How often the countdown re-renders. Default 100 ms gives a
  /// smooth-looking sweep without causing jank.
  final Duration tickInterval;

  /// Called exactly once when the timer hits zero.
  final VoidCallback onElapsed;

  /// Diameter in logical pixels.
  final double size;

  const FallCountdownRing({
    super.key,
    required this.onElapsed,
    this.duration = const Duration(seconds: 30),
    this.tickInterval = const Duration(milliseconds: 100),
    this.size = 200,
  });

  @override
  State<FallCountdownRing> createState() => _FallCountdownRingState();
}

class _FallCountdownRingState extends State<FallCountdownRing> {
  late Duration _remaining;
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.tickInterval, (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= widget.tickInterval;
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _timer?.cancel();
          if (!_fired) {
            _fired = true;
            // Defer the callback so consumers calling
            // ``Navigator.pop`` from inside [onElapsed] don't trigger
            // setState during build.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.onElapsed(),
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        widget.duration.inMilliseconds == 0
            ? 0.0
            : 1.0 - _remaining.inMilliseconds / widget.duration.inMilliseconds;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          ringColor: theme.colorScheme.error,
          backgroundColor:
              theme.colorScheme.error.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_remaining.inSeconds}',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'giây',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final stroke = 8.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    final sweep = -2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.ringColor != ringColor ||
        old.backgroundColor != backgroundColor;
  }
}
