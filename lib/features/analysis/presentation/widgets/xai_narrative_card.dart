import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_detail_entity.dart';

class XaiNarrativeCard extends StatefulWidget {
  final String explanation;
  final AiExplanation? aiExplanation;

  const XaiNarrativeCard({
    super.key,
    required this.explanation,
    this.aiExplanation,
  });

  @override
  State<XaiNarrativeCard> createState() => _XaiNarrativeCardState();
}

class _XaiNarrativeCardState extends State<XaiNarrativeCard> {
  bool _isExpanded = false;

  String get _primaryText {
    final ai = widget.aiExplanation;
    if (ai != null && ai.shortText.isNotEmpty) return ai.shortText;
    return widget.explanation;
  }

  String get _clinicalNote {
    final ai = widget.aiExplanation;
    if (ai == null) return '';
    return ai.clinicalNote;
  }

  List<String> get _actions {
    final ai = widget.aiExplanation;
    if (ai == null) return const [];
    return ai.recommendedActions;
  }

  bool get _hasStructuredExtras =>
      _clinicalNote.trim().isNotEmpty || _actions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final primary = _primaryText;
    final canExpand = _hasStructuredExtras || primary.length > 80;

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
              const Icon(Icons.auto_awesome, color: AppColors.info, size: 20),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Kết luận của AI',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AnimatedCrossFade(
            firstChild: Text(
              primary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            secondChild: _ExpandedNarrative(
              primaryText: primary,
              clinicalNote: _clinicalNote,
              actions: _actions,
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          if (canExpand) ...[
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
          ],
        ],
      ),
    );
  }
}

class _ExpandedNarrative extends StatelessWidget {
  final String primaryText;
  final String clinicalNote;
  final List<String> actions;

  const _ExpandedNarrative({
    required this.primaryText,
    required this.clinicalNote,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final showClinical = clinicalNote.trim().isNotEmpty;
    final showActions = actions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primaryText,
          style: AppTextStyles.body.copyWith(height: 1.5),
        ),
        if (showClinical) ...[
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Ghi chú chuyên môn',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          Text(
            clinicalNote,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        if (showActions) ...[
          const SizedBox(height: AppSpacing.gapMd),
          Text(
            'Hành động đề xuất',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.gapXs),
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      action,
                      style: AppTextStyles.body.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
