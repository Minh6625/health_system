import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shimmer placeholder hiển thị khi đang fetch dữ liệu.
/// Dùng flutter_animate (đã có trong pubspec) thay vì thêm lib riêng.
class ShimmerSleepLoading extends StatelessWidget {
  const ShimmerSleepLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Hero card placeholder
          _ShimmerBox(height: 140, radius: 22)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: const Color(0x33FFFFFF),
              ),

          const SizedBox(height: 20),

          // Section title placeholder
          _ShimmerBox(height: 16, width: 140, radius: 6)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                delay: 100.ms,
                duration: 1200.ms,
                color: const Color(0x33FFFFFF),
              ),

          const SizedBox(height: 12),

          // Donut chart placeholder
          Center(
            child: _ShimmerBox(height: 180, width: 180, radius: 90)
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  delay: 200.ms,
                  duration: 1200.ms,
                  color: const Color(0x33FFFFFF),
                ),
          ),

          const SizedBox(height: 20),

          // Section title placeholder
          _ShimmerBox(height: 16, width: 120, radius: 6)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                delay: 150.ms,
                duration: 1200.ms,
                color: const Color(0x33FFFFFF),
              ),

          const SizedBox(height: 12),

          // MetricTile x3 placeholders
          for (int i = 0; i < 3; i++) ...[
            Row(
              children: [
                _ShimmerBox(height: 38, width: 38, radius: 10)
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      delay: Duration(milliseconds: 100 * i),
                      duration: 1200.ms,
                      color: const Color(0x33FFFFFF),
                    ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShimmerBox(height: 16, radius: 6)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                        delay: Duration(milliseconds: 100 * i + 50),
                        duration: 1200.ms,
                        color: const Color(0x33FFFFFF),
                      ),
                ),
                const SizedBox(width: 16),
                _ShimmerBox(height: 16, width: 60, radius: 6)
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      delay: Duration(milliseconds: 100 * i + 80),
                      duration: 1200.ms,
                      color: const Color(0x33FFFFFF),
                    ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 8),

          // Bar chart placeholder
          _ShimmerBox(height: 120, radius: 14)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                delay: 300.ms,
                duration: 1200.ms,
                color: const Color(0x33FFFFFF),
              ),
        ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const _ShimmerBox({
    required this.height,
    this.width,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E4A),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
