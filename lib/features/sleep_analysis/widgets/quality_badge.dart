import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Badge hiển thị nhãn chất lượng giấc ngủ (Tốt / Trung bình / Kém)
/// với màu sắc tương ứng theo Design Guideline.
class QualityBadge extends StatelessWidget {
  final SleepSession session;
  final double fontSize;

  const QualityBadge({
    super.key,
    required this.session,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapMd, vertical: 5),
      decoration: BoxDecoration(
        color: session.qualityColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.radiusXl),
        border: Border.all(
          color: session.qualityColor.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        session.qualityLabelVi,
        style: TextStyle(
          color: session.qualityColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
