import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppRadii {
  AppRadii._();

  // Radius hệ thống
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;

  static final BorderRadius cardRadius = BorderRadius.circular(radiusLg);
  static final BorderRadius activeNavIndicatorRadius = BorderRadius.circular(
    radiusXxl,
  );
  static final BorderRadius pillRadius = BorderRadius.circular(50.0);
}

class AppShadows {
  AppShadows._();

  // Shadow cực nhẹ; ưu tiên phân tách bằng surface + stroke
  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.04),
      blurRadius: 8.0,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.08),
      blurRadius: 16.0,
      offset: const Offset(0, 4),
    ),
  ];
}
