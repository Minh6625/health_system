import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Hero status (28-30sp, SemiBold/Bold)
  static const TextStyle displayCompact = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // Tên block (20sp, SemiBold)
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // Nhịp tim, SpO2, v.v. (24-28sp, Bold)
  static const TextStyle vitalValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700, // Bold
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // Text chính lớn hơn, dùng cho family module (17sp, Regular)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Text chính (16-17sp, Regular/Medium)
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Timestamp, hint (14sp, Medium)
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Bottom nav (12-13sp, Medium/SemiBold)
  static const TextStyle navLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static const TextStyle navLabelActive = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.brandPrimary,
    height: 1.2,
  );
}
