import 'package:flutter/material.dart';

// @deprecated - Use shared/presentation/theme/app_colors.dart instead
// This file is kept for backward compatibility only.
// Mapping: AppColors.primary → AppColors.brandPrimary (shared)
//          AppColors.primaryLight → AppColors.brandPrimaryLight (shared)
//          AppColors.danger → AppColors.critical (shared)
class AppColors {
  static const Color primary = Color(0xFF2F80ED);
  static const Color primaryLight = Color(0xFF56CCF2);
  static const Color danger = Colors.red;

  const AppColors._();
}
