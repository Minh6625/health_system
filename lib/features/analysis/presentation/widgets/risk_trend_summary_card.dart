import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../domain/entities/risk_history_entity.dart';

class RiskTrendSummaryCard extends StatelessWidget {
  final RiskHistorySummary summary;

  const RiskTrendSummaryCard({super.key, required this.summary});

  String _formatScore(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  Widget _buildStatsHeader(bool compact) {
    final averageBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Điểm sức khoẻ trung bình', style: AppTextStyles.caption),
        Text(
          _formatScore(summary.healthAverage),
          style: AppTextStyles.displayCompact.copyWith(fontSize: 32),
        ),
      ],
    );

    final highLowBlock = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          'Cao nhất: ${_formatScore(summary.healthHighest)}',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.gapXs),
        Text(
          'Thấp nhất: ${_formatScore(summary.healthLowest)}',
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          averageBlock,
          const SizedBox(height: AppSpacing.gapMd),
          highLowBlock,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: averageBlock),
        const SizedBox(width: AppSpacing.gapMd),
        Flexible(child: highLowBlock),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.gapLg),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsHeader(compact),
              const SizedBox(height: AppSpacing.gapLg),
              if (summary.healthTrendPoints.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SimpleLinePainter(
                      data: summary.healthTrendPoints,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SimpleLinePainter extends CustomPainter {
  final List<int> data;

  _SimpleLinePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final path = Path();
    final double stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double normalizedY = (data[i] - minVal) / range;
      final double y = size.height - (normalizedY * size.height * 0.9);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
