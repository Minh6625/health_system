import 'package:flutter/material.dart';

import '../../../../shared/presentation/theme/app_colors.dart';

/// Shared health-score trend chart used by the risk preview / history
/// trend cards. Renders a line plot with:
///
/// - Y-axis ticks at 0 / 50 / 100 (health score domain, higher = better).
/// - Threshold lines at 60 ("Cần theo dõi") and 80 ("Ổn định") so the user
///   can see at a glance which zone each point sits in.
/// - X-axis ticks (1..N or supplied [xLabels]).
/// - Tappable points: tapping near a point highlights it and shows a
///   tooltip with the health score (and the x-label when supplied).
///
/// The chart paints itself via [CustomPainter] so it has zero dependencies
/// outside the Flutter SDK + this app's theme.
class HealthScoreTrendChart extends StatefulWidget {
  const HealthScoreTrendChart({
    super.key,
    required this.data,
    this.xLabels,
    this.height = 160,
  });

  /// Health-score data points (0..100, higher is better).
  final List<int> data;

  /// Optional per-point x-axis labels. Defaults to "1" .. "N".
  final List<String>? xLabels;

  final double height;

  @override
  State<HealthScoreTrendChart> createState() =>
      _HealthScoreTrendChartState();
}

class _HealthScoreTrendChartState extends State<HealthScoreTrendChart> {
  int? _selectedIndex;

  // Outer chart margins reserved for the axis labels.
  static const double _leftMargin = 28;
  static const double _rightMargin = 12;
  static const double _topMargin = 12;
  static const double _bottomMargin = 22;

  void _handleTap(Offset localPos, Size size) {
    final plotLeft = _leftMargin;
    final plotRight = size.width - _rightMargin;
    final plotWidth = plotRight - plotLeft;
    if (widget.data.length <= 1 || plotWidth <= 0) return;

    final stepX = plotWidth / (widget.data.length - 1);
    final relX = (localPos.dx - plotLeft).clamp(0, plotWidth);
    final index = (relX / stepX).round().clamp(0, widget.data.length - 1);
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return SizedBox(height: widget.height);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, widget.height);
          return GestureDetector(
            // Translucent so a vertical pan starting on the chart still
            // reaches the enclosing scroll view (we only register a tap
            // handler, so the gesture arena gives drags to the scroll
            // view by default).
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) =>
                _handleTap(details.localPosition, size),
            child: CustomPaint(
              painter: _ChartPainter(
                data: widget.data,
                xLabels: widget.xLabels,
                selectedIndex: _selectedIndex,
                leftMargin: _leftMargin,
                rightMargin: _rightMargin,
                topMargin: _topMargin,
                bottomMargin: _bottomMargin,
              ),
              size: size,
            ),
          );
        },
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.data,
    required this.xLabels,
    required this.selectedIndex,
    required this.leftMargin,
    required this.rightMargin,
    required this.topMargin,
    required this.bottomMargin,
  });

  final List<int> data;
  final List<String>? xLabels;
  final int? selectedIndex;
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double bottomMargin;

  // Health domain is fixed 0..100 so all charts share the same y-range and
  // threshold positions.
  static const double _yMin = 0;
  static const double _yMax = 100;
  static const double _watchThreshold = 60;
  static const double _stableThreshold = 80;

  Offset _pointAt(int index, Rect plot) {
    final stepX = data.length > 1
        ? plot.width / (data.length - 1)
        : plot.width / 2;
    final x = data.length > 1
        ? plot.left + index * stepX
        : plot.left + plot.width / 2;
    final v = data[index].toDouble().clamp(_yMin, _yMax);
    final y = plot.bottom -
        ((v - _yMin) / (_yMax - _yMin)) * plot.height;
    return Offset(x, y);
  }

  double _yFor(double value, Rect plot) =>
      plot.bottom - ((value - _yMin) / (_yMax - _yMin)) * plot.height;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      leftMargin,
      topMargin,
      size.width - rightMargin,
      size.height - bottomMargin,
    );

    _drawYAxis(canvas, plot);
    _drawThreshold(canvas, plot, _watchThreshold, AppColors.warning);
    _drawThreshold(canvas, plot, _stableThreshold, AppColors.success);
    _drawLineAndPoints(canvas, plot);
    _drawXAxis(canvas, plot);
    _drawTooltip(canvas, plot);
  }

  void _drawYAxis(Canvas canvas, Rect plot) {
    final gridPaint = Paint()
      ..color = AppColors.strokeSoft.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final tick in const [0, 50, 100]) {
      final y = _yFor(tick.toDouble(), plot);
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        gridPaint,
      );
      _paintText(
        canvas,
        text: '$tick',
        offset: Offset(plot.left - 4, y),
        anchor: _TextAnchor.right,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      );
    }
  }

  void _drawXAxis(Canvas canvas, Rect plot) {
    for (int i = 0; i < data.length; i++) {
      final p = _pointAt(i, plot);
      final label = (xLabels != null && i < xLabels!.length)
          ? xLabels![i]
          : (i + 1).toString();
      _paintText(
        canvas,
        text: label,
        offset: Offset(p.dx, plot.bottom + 4),
        anchor: _TextAnchor.topCenter,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      );
    }
  }

  void _drawThreshold(Canvas canvas, Rect plot, double value, Color color) {
    final y = _yFor(value, plot);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    var x = plot.left;
    while (x < plot.right) {
      final end = (x + dashWidth).clamp(plot.left, plot.right).toDouble();
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + dashGap;
    }
    // Right-edge label so the threshold stays self-explanatory.
    _paintText(
      canvas,
      text: value.toInt().toString(),
      offset: Offset(plot.right, y - 2),
      anchor: _TextAnchor.bottomRight,
      style: TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _drawLineAndPoints(Canvas canvas, Rect plot) {
    final linePaint = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < data.length; i++) {
      final p = _pointAt(i, plot);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fillPath.moveTo(p.dx, plot.bottom);
        fillPath.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    if (data.length > 1) {
      final lastX = _pointAt(data.length - 1, plot).dx;
      fillPath.lineTo(lastX, plot.bottom);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }
    canvas.drawPath(path, linePaint);

    final pointFill = Paint()..color = AppColors.brandPrimary;
    final pointStroke = Paint()
      ..color = AppColors.bgSurface
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < data.length; i++) {
      final p = _pointAt(i, plot);
      canvas.drawCircle(p, 3.5, pointFill);
      canvas.drawCircle(p, 3.5, pointStroke);
    }
  }

  void _drawTooltip(Canvas canvas, Rect plot) {
    final idx = selectedIndex;
    if (idx == null || idx < 0 || idx >= data.length) return;

    final p = _pointAt(idx, plot);

    final guidePaint = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(p.dx, plot.top),
      Offset(p.dx, plot.bottom),
      guidePaint,
    );

    canvas.drawCircle(p, 5.5, Paint()..color = AppColors.brandPrimary);
    canvas.drawCircle(
      p,
      5.5,
      Paint()
        ..color = AppColors.bgSurface
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    final dateLabel = (xLabels != null && idx < xLabels!.length)
        ? xLabels![idx]
        : 'Ngày ${idx + 1}';
    final value = data[idx];

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$dateLabel\n',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '$value điểm',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final boxWidth = tp.width + 14;
    final boxHeight = tp.height + 8;
    var boxLeft = p.dx - boxWidth / 2;
    boxLeft = boxLeft.clamp(plot.left, plot.right - boxWidth);
    var boxTop = p.dy - boxHeight - 8;
    if (boxTop < plot.top) boxTop = p.dy + 8;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.bgSurface);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.strokeSoft
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    tp.paint(canvas, Offset(boxLeft + 7, boxTop + 4));
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required _TextAnchor anchor,
    required TextStyle style,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    Offset paintOffset;
    switch (anchor) {
      case _TextAnchor.right:
        paintOffset =
            Offset(offset.dx - tp.width, offset.dy - tp.height / 2);
        break;
      case _TextAnchor.topCenter:
        paintOffset = Offset(offset.dx - tp.width / 2, offset.dy);
        break;
      case _TextAnchor.bottomRight:
        paintOffset = Offset(offset.dx - tp.width, offset.dy - tp.height);
        break;
    }
    tp.paint(canvas, paintOffset);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.leftMargin != leftMargin ||
        oldDelegate.rightMargin != rightMargin ||
        oldDelegate.topMargin != topMargin ||
        oldDelegate.bottomMargin != bottomMargin;
  }
}

enum _TextAnchor { right, topCenter, bottomRight }
