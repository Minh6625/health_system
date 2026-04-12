import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class DirtyFooterBar extends StatelessWidget {
  final bool isVisible;
  final bool isSaving;
  final VoidCallback onSave;

  const DirtyFooterBar({
    super.key,
    required this.isVisible,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: isVisible ? 100 : 0,
      child: isVisible
          ? Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sectionGapLg,
                vertical: AppSpacing.sectionGapMd,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: AppShadows.elevatedShadow,
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Có thay đổi chưa lưu',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            'Nhớ biểu quyết trước khi thoát',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sectionGapMd),
                    ElevatedButton(
                      onPressed: isSaving ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sectionGapXl,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.radiusMd),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Lưu thay đổi', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
