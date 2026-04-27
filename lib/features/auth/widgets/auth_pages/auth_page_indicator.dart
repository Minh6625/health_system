import 'package:flutter/material.dart';

/// Animated dot indicator for the auth `PageView`.
///
/// The active dot stretches from 8px to 32px and brightens, while inactive
/// dots stay small and translucent. Kept in its own widget so the active
/// page state is the only input - the indicator stays stateless and can be
/// dropped into any horizontal `PageView` of arbitrary length by tweaking
/// `pageCount`.
class AuthPageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;

  const AuthPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          pageCount,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: currentPage == index ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: currentPage == index
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
