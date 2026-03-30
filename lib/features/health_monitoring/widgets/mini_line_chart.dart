import 'package:flutter/material.dart';

/// A lightweight, dependency-free line chart using CustomPainter.
/// Draws one or more lines with smooth curves and a gradient fill under the first line.
class MiniLineChart extends StatefulWidget {
  /// Each list of double represents a line.
  final List<List<double>> linesData;
  final List<Color> lineColors;
  final double height;
  final bool showPoints;
  final bool showAverageLine;
  final List<String>? xLabels; // optional x labels

  const MiniLineChart({
    super.key,
    required this.linesData,
    required this.lineColors,
    this.height = 140,
    this.showPoints = true,
    this.showAverageLine = true,
    this.xLabels,
  });

  @override
  State<MiniLineChart> createState() => _MiniLineChartState();
}

class _MiniLineChartState extends State<MiniLineChart> {
  Offset? _touchedPosition;

  @override
  Widget build(BuildContext context) {
    if (widget.linesData.isEmpty || widget.linesData.first.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('Không có dữ liệu')),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: GestureDetector(
        onPanDown: (details) => setState(() => _touchedPosition = details.localPosition),
        onPanUpdate: (details) => setState(() => _touchedPosition = details.localPosition),
        onPanEnd: (_) => setState(() => _touchedPosition = null),
        onPanCancel: () => setState(() => _touchedPosition = null),
        child: CustomPaint(
          painter: _LineChartPainter(
            linesData: widget.linesData,
            lineColors: widget.lineColors,
            showPoints: widget.showPoints,
            showAverageLine: widget.showAverageLine,
            xLabels: widget.xLabels,
            touchedPosition: _touchedPosition,
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<List<double>> linesData;
  final List<Color> lineColors;
  final bool showPoints;
  final bool showAverageLine;
  final List<String>? xLabels;
  final Offset? touchedPosition;

  _LineChartPainter({
    required this.linesData,
    required this.lineColors,
    required this.showPoints,
    required this.showAverageLine,
    this.xLabels,
    this.touchedPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (linesData.isEmpty || linesData.first.isEmpty) return;

    // Find global min and max to scale the chart
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    int maxLen = 0;

    for (var line in linesData) {
      if (line.length > maxLen) maxLen = line.length;
      for (var val in line) {
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    if (maxVal == minVal) {
      minVal -= 10;
      maxVal += 10;
    }

    // Add padding to top and bottom (10% of range)
    final range = maxVal - minVal;
    minVal -= range * 0.1;
    maxVal += range * 0.1;

    // Margins for axes
    final double marginLeft = 28.0;
    final double marginBottom = 20.0;
    final chartWidth = size.width - marginLeft;
    final chartHeight = size.height - marginBottom;

    final scaleY = chartHeight / (maxVal - minVal);
    final stepX = chartWidth / (maxLen > 1 ? maxLen - 1 : 1);

    // Draw Y axis labels
    _drawText(canvas, maxVal.toStringAsFixed(0), const Offset(0, 0));
    _drawText(canvas, minVal.toStringAsFixed(0), Offset(0, chartHeight - 12));
    _drawText(canvas, ((maxVal + minVal) / 2).toStringAsFixed(0), Offset(0, chartHeight / 2 - 6));

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(marginLeft, chartHeight), Offset(size.width, chartHeight), gridPaint);
    canvas.drawLine(Offset(marginLeft, chartHeight / 2), Offset(size.width, chartHeight / 2), gridPaint);
    canvas.drawLine(Offset(marginLeft, 0), Offset(size.width, 0), gridPaint);

    // Draw X axis labels if provided
    if (xLabels != null) {
      for (int i = 0; i < xLabels!.length; i++) {
        final x = marginLeft + i * stepX;
        _drawText(canvas, xLabels![i], Offset(x - 10, chartHeight + 4));
      }
    }

    List<List<Offset>> allPoints = [];

    // Draw lines
    for (int i = 0; i < linesData.length; i++) {
      final line = linesData[i];
      final color = lineColors.length > i ? lineColors[i] : Colors.blue;
      final path = Path();
      List<Offset> currentPoints = [];

      if (line.isEmpty) {
        allPoints.add([]);
        continue;
      }

      final startY = chartHeight - (line[0] - minVal) * scaleY;
      path.moveTo(marginLeft, startY);
      currentPoints.add(Offset(marginLeft, startY));

      for (int j = 1; j < line.length; j++) {
        final x = marginLeft + j * stepX;
        final y = chartHeight - (line[j] - minVal) * scaleY;
        currentPoints.add(Offset(x, y));
        
        // Simple smoothing using cubic bezier
        final prevX = marginLeft + (j - 1) * stepX;
        final prevY = chartHeight - (line[j - 1] - minVal) * scaleY;
        
        final controlX1 = prevX + (x - prevX) / 2;
        final controlY1 = prevY;
        final controlX2 = prevX + (x - prevX) / 2;
        final controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }
      
      allPoints.add(currentPoints);

      // Fill area under the first line
      if (i == 0) {
        final fillPath = Path.from(path);
        fillPath.lineTo(size.width, chartHeight);
        fillPath.lineTo(marginLeft, chartHeight);
        fillPath.close();

        final fillPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(marginLeft, 0, chartWidth, chartHeight));

        canvas.drawPath(fillPath, fillPaint);
      }

      // Draw stroke
      final strokePaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, strokePaint);

      // Draw Average Line
      if (showAverageLine && line.isNotEmpty) {
        double sum = 0;
        for (var val in line) { sum += val; }
        final double avg = sum / line.length;
        final avgY = chartHeight - (avg - minVal) * scaleY;

        final avgPaint = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        const dashWidth = 4.0;
        const dashSpace = 4.0;
        double startX = marginLeft;
        while (startX < size.width) {
          canvas.drawLine(Offset(startX, avgY), Offset(startX + dashWidth, avgY), avgPaint);
          startX += dashWidth + dashSpace;
        }
      }

      // Draw Points
      if (showPoints && line.isNotEmpty) {
        final pointPaint = Paint()..color = color..style = PaintingStyle.fill;
        final borderPaint = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;

        for (var pt in currentPoints) {
          canvas.drawCircle(pt, 4, borderPaint);
          canvas.drawCircle(pt, 3, pointPaint);
        }
      }
    }

    // Draw interactive tooltip if touched
    if (touchedPosition != null && touchedPosition!.dx >= marginLeft && touchedPosition!.dx <= size.width) {
      // Find closest X index
      final double normalizedX = touchedPosition!.dx - marginLeft;
      int closestIndex = (normalizedX / stepX).round();
      if (closestIndex < 0) closestIndex = 0;
      if (closestIndex >= maxLen) closestIndex = maxLen - 1;

      final double exactX = marginLeft + closestIndex * stepX;

      // Draw vertical line indicator
      final indicatorPaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.5)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(exactX, 0), Offset(exactX, chartHeight), indicatorPaint);

      // Collect values for this index
      List<String> tooltipLines = [];
      if (xLabels != null && xLabels!.length > closestIndex) {
        tooltipLines.add(xLabels![closestIndex]);
      }
      
      for (int i = 0; i < linesData.length; i++) {
        if (linesData[i].length > closestIndex) {
          tooltipLines.add(linesData[i][closestIndex].toStringAsFixed(1));
          
          // Draw a highlight circle on the exact point
          final color = lineColors.length > i ? lineColors[i] : Colors.blue;
          final ptY = chartHeight - (linesData[i][closestIndex] - minVal) * scaleY;
          final highlightPaint = Paint()..color = color..style = PaintingStyle.fill;
          final borderPaint = Paint()..color = Colors.white..strokeWidth = 3..style = PaintingStyle.stroke;
          canvas.drawCircle(Offset(exactX, ptY), 6, borderPaint);
          canvas.drawCircle(Offset(exactX, ptY), 5, highlightPaint);
        }
      }

      // Draw tooltip box
      final tooltipText = tooltipLines.join('\n');
      final textSpan = TextSpan(text: tooltipText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();

      final boxWidth = textPainter.width + 16;
      final boxHeight = textPainter.height + 12;
      double boxX = exactX - boxWidth / 2;
      double boxY = touchedPosition!.dy - boxHeight - 10;
      
      if (boxY < 0) boxY = 10;
      if (boxX < marginLeft) boxX = marginLeft;
      if (boxX + boxWidth > size.width) boxX = size.width - boxWidth;

      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight), const Radius.circular(8));
      canvas.drawRRect(rrect, Paint()..color = Colors.black87);
      textPainter.paint(canvas, Offset(boxX + 8, boxY + 6));
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final textSpan = TextSpan(text: text, style: TextStyle(color: Colors.grey.shade600, fontSize: 10));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.linesData != linesData ||
           oldDelegate.lineColors != lineColors ||
           oldDelegate.showPoints != showPoints ||
           oldDelegate.showAverageLine != showAverageLine ||
           oldDelegate.xLabels != xLabels ||
           oldDelegate.touchedPosition != touchedPosition;
  }
}
