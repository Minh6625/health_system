import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandPrimary,
        primary: AppColors.brandPrimary,
      ),
      scaffoldBackgroundColor: AppColors.bgPrimary,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: AppTextStyles.sectionTitle.fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.brandPrimary,
        unselectedItemColor: AppColors.textSecondary,
      ),
    );
  }

  const AppTheme._();
}
