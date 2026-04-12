import 'package:flutter/material.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';

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
    );
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    // Defer repeat() to post-frame to prevent mouse_tracker assertion when
    // the skeleton is swapped out during the same frame it starts animating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.stop();
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
              // Shimmer gradient — decorative skeleton colors, not semantic
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
        _skeletonBox(height: 44, radius: AppRadii.radiusMd),
        SizedBox(height: AppSpacing.gapLg),
        // 2×2 card grid
        Row(
          children: [
            Expanded(child: _skeletonBox(height: 140, radius: AppRadii.radiusLg)),
            SizedBox(width: AppSpacing.gapMd),
            Expanded(child: _skeletonBox(height: 140, radius: AppRadii.radiusLg)),
          ],
        ),
        SizedBox(height: AppSpacing.gapMd),
        Row(
          children: [
            Expanded(child: _skeletonBox(height: 140, radius: AppRadii.radiusLg)),
            SizedBox(width: AppSpacing.gapMd),
            Expanded(child: _skeletonBox(height: 140, radius: AppRadii.radiusLg)),
          ],
        ),
        SizedBox(height: AppSpacing.gapMd),
        // Blood pressure card (wide)
        _skeletonBox(height: 100, radius: AppRadii.radiusLg),
        SizedBox(height: AppSpacing.sectionGapXl.toDouble()),
        // Quick actions
        _skeletonBox(height: 76, radius: AppRadii.radiusMd),
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
