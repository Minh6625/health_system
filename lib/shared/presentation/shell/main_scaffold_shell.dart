import 'package:flutter/material.dart';

class MainScaffoldShell extends StatelessWidget {
  final Widget child;
  final Widget bottomNavigation;
  final Widget? stickyBottomBar;
  final Color? backgroundColor;

  const MainScaffoldShell({
    super.key,
    required this.child,
    required this.bottomNavigation,
    this.stickyBottomBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(child: child),
          // ignore: use_null_aware_elements
          if (stickyBottomBar != null) stickyBottomBar!,
          bottomNavigation,
        ],
      ),
    );
  }
}
