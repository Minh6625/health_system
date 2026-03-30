import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // Horizontal padding màn (20dp)
  static const EdgeInsets screenHorizontalPadding = EdgeInsets.symmetric(
    horizontal: 20.0,
  );

  // Khoảng cách section
  static const double sectionGapSm = 12.0;
  static const double sectionGapMd = 16.0;
  static const double sectionGapLg = 20.0;
  static const double sectionGapXl = 24.0;

  // Card padding (16dp)
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  // Khoảng gap nhỏ
  static const double gapXs = 4.0;
  static const double gapSm = 8.0;
  static const double gapMd = 12.0;
  static const double gapLg = 16.0;

  // Sticky bottom CTA gap với nav (12dp)
  static const double stickyBottomActionGap = 12.0;

  // Touch targets (tối thiểu 48dp)
  static const double minTouchTargetSize = 48.0;
}
