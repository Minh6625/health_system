import 'package:flutter/material.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';

class RiskTrendPreviewCard extends StatelessWidget {
  final List<int> trend7d;

  const RiskTrendPreviewCard({super.key, required this.trend7d});

  @override
  Widget build(BuildContext context) {
    if (trend7d.isEmpty) return const SizedBox.shrink();

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
          const Text('Xu hướng 7 ngày', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.gapMd),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(painter: _TrendChartPainter(data: trend7d)),
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(AppColors.success, 'Ổn định'),
              const SizedBox(width: AppSpacing.gapMd),
              _buildLegend(AppColors.warning, 'Tăng nhẹ'),
              const SizedBox(width: AppSpacing.gapMd),
              _buildLegend(AppColors.critical, 'Nguy hiểm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.gapXs),
        Text(label, style: AppTextStyles.navLabel),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<int> data;

  _TrendChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.fill;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1 : (maxVal - minVal);

    final path = Path();
    final double stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      // y is inverted (0 is top)
      final double normalizedY = (data[i] - minVal) / range;
      final double y =
          size.height - (normalizedY * size.height * 0.8) - (size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
