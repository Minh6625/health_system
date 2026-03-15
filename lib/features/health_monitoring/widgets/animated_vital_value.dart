import 'package:flutter/material.dart';

/// A widget that animates smoothly when a numeric vital value changes.
/// Uses [AnimatedSwitcher] with a size+fade transition so that new numbers
/// slide in while old numbers fade out — creating a premium streaming feel.
class AnimatedVitalValue extends StatelessWidget {
  /// The formatted string of the current value (e.g. "72", "98.6", "--")
  final String value;

  /// Font size of the main number. Defaults to 28.
  final double fontSize;

  /// Color of the number text.
  final Color color;

  /// Duration of the crossfade/slide transition. Defaults to 500ms.
  final Duration duration;

  const AnimatedVitalValue({
    super.key,
    required this.value,
    required this.color,
    this.fontSize = 28,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey(value),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
