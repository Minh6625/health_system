import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';

/// Collapsible "Kiến thức y khoa" card. Replaces the always-expanded info
/// box that pushed the SOS button below the fold for critical readings.
///
/// Default state: 2-line preview + "Xem thêm". Tap anywhere on the card to
/// expand to full text + "Thu gọn".
class VitalEducationCard extends StatefulWidget {
  const VitalEducationCard({
    super.key,
    required this.text,
    this.title = 'Kiến thức y khoa',
  });

  final String text;
  final String title;

  @override
  State<VitalEducationCard> createState() => _VitalEducationCardState();
}

class _VitalEducationCardState extends State<VitalEducationCard> {
  bool _expanded = false;

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppStateColors.infoBg,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        borderRadius: AppRadii.cardRadius,
        onTap: _toggle,
        child: Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.gapSm),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  widget.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    height: 1.4,
                    color: AppColors.info,
                  ),
                ),
                secondChild: Text(
                  widget.text,
                  style: AppTextStyles.body.copyWith(
                    height: 1.4,
                    color: AppColors.info,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.gapXs),
              Text(
                _expanded ? 'Thu gọn' : 'Xem thêm',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
