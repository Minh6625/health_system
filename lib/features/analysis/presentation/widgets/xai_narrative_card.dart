import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class XaiNarrativeCard extends StatefulWidget {
  final String explanation;

  const XaiNarrativeCard({super.key, required this.explanation});

  @override
  State<XaiNarrativeCard> createState() => _XaiNarrativeCardState();
}

class _XaiNarrativeCardState extends State<XaiNarrativeCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: AppStateColors.infoBg,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.info,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'AI Giải thích',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AnimatedCrossFade(
            firstChild: Text(
              widget.explanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(height: 1.5),
            ),
            secondChild: Text(
              widget.explanation,
              style: AppTextStyles.body.copyWith(height: 1.5),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          if (widget.explanation.length > 80) ...[
            const SizedBox(height: AppSpacing.gapSm),
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? 'Thu gọn' : 'Xem thêm',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
