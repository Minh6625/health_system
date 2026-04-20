import 'package:flutter/material.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';

/// Small (i) icon button that opens a ModalBottomSheet explaining sleep phases.
///
/// Usage:
/// ```dart
/// Row(children: [
///   Text('Cơ cấu giấc ngủ'),
///   InfoTooltipIcon(topic: SleepInfoTopic.phases),
/// ])
/// ```
class InfoTooltipIcon extends StatelessWidget {
  final SleepInfoTopic topic;

  const InfoTooltipIcon({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x1A48D6FF),
          border: Border.all(color: const Color(0x5548D6FF), width: 1),
        ),
        alignment: Alignment.center,
        child: const Text(
          'i',
          style: TextStyle(
            color: Color(0xFF48D6FF),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1E38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.radiusXl)),
      ),
      isScrollControlled: true,
      builder: (_) => _SleepInfoSheet(topic: topic),
    );
  }
}

// ── Topic Enum ────────────────────────────────────────────────────────────────

enum SleepInfoTopic { phases, trend }

// ── Bottom Sheet Content ──────────────────────────────────────────────────────

class _SleepInfoSheet extends StatelessWidget {
  final SleepInfoTopic topic;

  const _SleepInfoSheet({required this.topic});

  @override
  Widget build(BuildContext context) {
    final items = topic == SleepInfoTopic.phases
        ? _phaseItems
        : _trendItems;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.gapLg, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A5580),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            topic == SleepInfoTopic.phases
                ? 'Các giai đoạn giấc ngủ là gì?'
                : 'Xu hướng 7 ngày là gì?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.gapLg),

          // Items
          ...items.map((item) => _InfoItem(
                icon: item.$1,
                color: item.$2,
                title: item.$3,
                description: item.$4,
              )),
        ],
      ),
    );
  }

  /// (icon, color, title, description)
  static const _phaseItems = [
    (
      Icons.hotel_rounded,
      Color(0xFFFFC400),
      'Thức giữa đêm',
      'Thời gian bạn tỉnh giấc trong đêm. Thức nhiều lần làm giấc ngủ kém chất lượng hơn.',
    ),
    (
      Icons.waves_rounded,
      Color(0xFF48A9D6),
      'Ngủ nông (Light Sleep)',
      'Giai đoạn chuyển tiếp giữa thức và ngủ sâu. Chiếm phần lớn giấc ngủ, giúp não bộ nghỉ ngơi nhẹ nhàng.',
    ),
    (
      Icons.bedtime_rounded,
      Color(0xFF3A5FCD),
      'Ngủ sâu (Deep Sleep)',
      'Giai đoạn phục hồi cơ thể quan trọng nhất. Giúp tái tạo tế bào, tăng sức đề kháng và củng cố trí nhớ dài hạn.',
    ),
    (
      Icons.psychology_rounded,
      Color(0xFF9C6ADE),
      'REM (Rapid Eye Movement)',
      'Giai đoạn mơ ngủ. Não bộ xử lý cảm xúc và củng cố trí nhớ ngắn hạn. Thiếu REM gây khó tập trung ban ngày.',
    ),
  ];

  static const _trendItems = [
    (
      Icons.bar_chart_rounded,
      Color(0xFF48A9D6),
      'Điểm chất lượng (0–100)',
      'Mỗi cột biểu thị điểm chất lượng giấc ngủ của một ngày. Điểm càng cao càng tốt.',
    ),
    (
      Icons.circle,
      Color(0xFF4CAF50),
      'Màu xanh lá: Tốt (≥ 70)',
      'Giấc ngủ đạt chất lượng tốt, đủ các giai đoạn ngủ sâu và REM.',
    ),
    (
      Icons.circle,
      Color(0xFFFFC400),
      'Màu vàng: Trung bình (50–69)',
      'Giấc ngủ chấp nhận được nhưng có thể cải thiện thêm.',
    ),
    (
      Icons.circle,
      Color(0xFFEF5350),
      'Màu đỏ: Kém (< 50)',
      'Giấc ngủ kém chất lượng. Nên điều chỉnh giờ ngủ hoặc tham khảo ý kiến bác sĩ.',
    ),
  ];
}

// ── Info Item ─────────────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _InfoItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gapLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF7A96B8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
