import 'package:flutter/material.dart';
import 'package:health_system/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
    );
  }

  const AppTheme._();
}
