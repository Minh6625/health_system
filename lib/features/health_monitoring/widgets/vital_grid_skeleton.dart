import 'package:flutter/material.dart';

/// A shimmer skeleton that mimics the layout of the Health Monitoring dashboard
/// (2-column vital card grid + wide blood pressure card) shown during initial load.
class VitalGridSkeleton extends StatefulWidget {
  const VitalGridSkeleton({super.key});

  @override
  State<VitalGridSkeleton> createState() => _VitalGridSkeletonState();
}

class _VitalGridSkeletonState extends State<VitalGridSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _skeletonBox({
    double height = 140,
    double? width,
    double radius = 16,
  }) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: const [
                Color(0xFFE8ECF0),
                Color(0xFFF5F7FA),
                Color(0xFFE8ECF0),
              ],
              transform: _SlideGradientTransform(_shimmer.value),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TimestampBadge skeleton
        _skeletonBox(height: 44, radius: 12),
        const SizedBox(height: 16),
        // 2×2 card grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: List.generate(4, (_) => _skeletonBox()),
        ),
        const SizedBox(height: 12),
        // Blood pressure card (wide)
        _skeletonBox(height: 100, radius: 16),
        const SizedBox(height: 24),
        // Quick actions
        _skeletonBox(height: 76, radius: 12),
      ],
    );
  }
}

/// A GradientTransform that slides the shimmer highlight horizontally.
class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}
