import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_colors.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:healthguard/shared/presentation/theme/app_text_styles.dart';

class DeviceInfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const DeviceInfoSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: AppSpacing.sectionGapSm),
          child: Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 18,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(AppRadii.radiusLg),
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}
