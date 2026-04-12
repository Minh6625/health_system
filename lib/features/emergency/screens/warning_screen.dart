import 'package:flutter/material.dart';
import 'package:healthguard/features/emergency/screens/manual_sos_screen.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class WarningScreen extends StatelessWidget {
  const WarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sectionGapXl),
              decoration: BoxDecoration(
                color: AppColors.critical.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sectionGapXl),
                decoration: BoxDecoration(
                  color: AppColors.critical.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManualSOSScreen(),
                        ),
                      );
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.critical,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.critical.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            size: 64,
                            color: AppColors.bgSurface,
                          ),
                          SizedBox(height: AppSpacing.gapSm),
                          Text(
                            'CHẠM ĐỂ GỌI',
                            style: TextStyle(
                              color: AppColors.bgSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'KHẨN CẤP (SOS)',
                            style: TextStyle(
                              color: AppColors.bgSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Nhấn vào nút bên trên nếu bạn hoặc người thân đang trong tình trạng nguy hiểm cần cấp cứu lập tức.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
