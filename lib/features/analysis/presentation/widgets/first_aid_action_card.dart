import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_report_entity.dart';

/// Static "what should I do right now" card placed under the AI conclusion
/// on the risk report detail screen. The content (title, color, bullets,
/// action buttons) varies by [RiskLevel] so the user gets level-appropriate
/// first-aid guidance instead of generic recommendations.
///
/// Action callbacks are wired by the parent screen because routing depends
/// on the active profile context. The "Gọi 115" button is built into this
/// widget — it dials `tel:115` via `url_launcher` and surfaces a snackbar
/// when the platform refuses to dial.
class FirstAidActionCard extends StatelessWidget {
  const FirstAidActionCard({
    super.key,
    required this.level,
    this.onMeasureAgain,
    this.onContactFamily,
    this.onViewDetails,
  });

  final RiskLevel level;

  /// Tapped on the secondary "Đo lại" action (medium / critical).
  final VoidCallback? onMeasureAgain;

  /// Tapped on the secondary "Báo người thân" action (medium / critical).
  /// In this app the contact list is the user's family caregivers, not a
  /// dedicated doctor directory.
  final VoidCallback? onContactFamily;

  /// Tapped on the low-severity primary action ("Xem chi tiết").
  final VoidCallback? onViewDetails;

  _FirstAidContent get _content => _firstAidContent(level);

  Future<void> _dialEmergency(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse('tel:115');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // fall through to the snackbar fallback
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Không thể mở trình quay số. Vui lòng tự gọi 115.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.gapLg),
      decoration: BoxDecoration(
        color: c.bgColor,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: c.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.icon, color: c.accent, size: 22),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Text(
                  c.title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapSm),
          Text(
            c.subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.gapMd),
          for (final step in c.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapSm),
                  Expanded(
                    child: Text(
                      step,
                      style: AppTextStyles.body.copyWith(
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.gapSm),
          _ActionRow(
            level: level,
            accent: c.accent,
            onCallEmergency: () => _dialEmergency(context),
            onMeasureAgain: onMeasureAgain,
            onContactFamily: onContactFamily,
            onViewDetails: onViewDetails,
          ),
        ],
      ),
    );
  }
}

class _FirstAidContent {
  const _FirstAidContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.bgColor,
    required this.borderColor,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color bgColor;
  final Color borderColor;
  final List<String> steps;
}

_FirstAidContent _firstAidContent(RiskLevel level) {
  switch (level) {
    case RiskLevel.critical:
      return _FirstAidContent(
        title: 'Cần xử trí ngay',
        subtitle:
            'Có dấu hiệu nguy cơ cao. Hãy thực hiện các bước sau và sẵn sàng gọi 115 nếu triệu chứng nặng lên.',
        icon: Icons.medical_services_rounded,
        accent: AppColors.critical,
        bgColor: AppStateColors.criticalBg,
        borderColor: AppColors.critical.withValues(alpha: 0.45),
        steps: const [
          'Ngồi hoặc nằm nghỉ ở nơi thoáng, hít thở chậm và đều.',
          'Đo lại huyết áp / nhịp tim sau 2–3 phút để đối chiếu.',
          'Không tự lái xe hoặc làm việc gắng sức.',
          'Gọi 115 ngay nếu đau ngực, khó thở, choáng ngất hoặc tê yếu một bên.',
          'Báo cho người thân biết tình trạng để được hỗ trợ.',
        ],
      );
    case RiskLevel.medium:
      return _FirstAidContent(
        title: 'Theo dõi sát',
        subtitle:
            'Một số chỉ số đang lệch khỏi ngưỡng bình thường. Theo dõi thêm và điều chỉnh sinh hoạt giúp ổn định lại.',
        icon: Icons.tips_and_updates_rounded,
        accent: AppColors.warning,
        bgColor: AppStateColors.warningBg,
        borderColor: AppColors.warning.withValues(alpha: 0.45),
        steps: const [
          'Uống đủ nước và nghỉ ngơi 15–30 phút trước khi đo lại.',
          'Ghi chép triệu chứng kèm theo (chóng mặt, mệt, hồi hộp...).',
          'Hạn chế gắng sức, cà phê và rượu trong 24 giờ tới.',
          'Nếu chỉ số vẫn lệch sau 1–2 lần đo lại, liên hệ bác sĩ để được tư vấn.',
        ],
      );
    case RiskLevel.low:
      return _FirstAidContent(
        title: 'Duy trì lối sống tốt',
        subtitle:
            'Sức khoẻ đang ổn định. Tiếp tục giữ thói quen lành mạnh để duy trì xu hướng tích cực.',
        icon: Icons.favorite_rounded,
        accent: AppColors.success,
        bgColor: AppStateColors.successBg,
        borderColor: AppColors.success.withValues(alpha: 0.40),
        steps: const [
          'Duy trì ngủ đủ 7–8 giờ và uống đủ 1.5–2 lít nước/ngày.',
          'Vận động nhẹ 30 phút/ngày (đi bộ, đạp xe, yoga).',
          'Tiếp tục đeo thiết bị để theo dõi xu hướng dài hạn.',
        ],
      );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.level,
    required this.accent,
    required this.onCallEmergency,
    required this.onMeasureAgain,
    required this.onContactFamily,
    required this.onViewDetails,
  });

  final RiskLevel level;
  final Color accent;
  final VoidCallback onCallEmergency;
  final VoidCallback? onMeasureAgain;
  final VoidCallback? onContactFamily;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    switch (level) {
      case RiskLevel.critical:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCallEmergency,
                icon: const Icon(Icons.phone_in_talk_rounded),
                label: const Text(
                  'Gọi 115',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                  ),
                ),
              ),
            ),
            if (onMeasureAgain != null) ...[
              const SizedBox(height: AppSpacing.gapSm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onMeasureAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Đo lại ngay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.critical,
                    side: BorderSide(
                      color: AppColors.critical.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      case RiskLevel.medium:
        return Row(
          children: [
            if (onMeasureAgain != null)
              Expanded(
                child: FilledButton.icon(
                  onPressed: onMeasureAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Đo lại'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                    ),
                  ),
                ),
              ),
            if (onMeasureAgain != null && onContactFamily != null)
              const SizedBox(width: AppSpacing.gapSm),
            if (onContactFamily != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onContactFamily,
                  icon: const Icon(Icons.contact_phone_rounded, size: 18),
                  label: const Text('Báo người thân'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                    ),
                  ),
                ),
              ),
          ],
        );
      case RiskLevel.low:
        if (onViewDetails == null) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Xem hướng dẫn duy trì'),
            style: TextButton.styleFrom(foregroundColor: accent),
          ),
        );
    }
  }
}
