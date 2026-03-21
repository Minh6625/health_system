import 'dart:math';
import 'package:flutter/material.dart';

/// A performant starry sky background using CustomPainter.
/// Draws static stars to avoid unnecessary rebuilds and battery drain.
class StarryBackground extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;

  const StarryBackground({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFF071220),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark background
        Container(color: backgroundColor),
        // Star layer
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _StarPainter(),
            ),
          ),
        ),
        // Content
        child,
      ],
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Seed for deterministic star placement
    final paint = Paint()..color = Colors.white;

    // Draw about 100-150 stars
    for (int i = 0; i < 120; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      
      // Random opacity for depth effect
      final opacity = 0.1 + random.nextDouble() * 0.4;
      paint.color = Colors.white.withValues(alpha: opacity);
      
      // Random scale bits (mostly tiny points)
      final radius = 0.4 + random.nextDouble() * 0.8;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
