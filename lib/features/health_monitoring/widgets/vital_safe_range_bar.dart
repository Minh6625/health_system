import 'package:flutter/material.dart';

import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
import 'vital_safe_range.dart';

/// 5-zone horizontal gauge showing where the patient's current value sits
/// relative to the medically safe range. Built from a [VitalSafeRange].
///
/// Layout:
///   [critical-low | warning-low | NORMAL | warning-high | critical-high]
///                                  ▼ marker on currentValue
///
/// The marker position is clamped so out-of-axis values still appear at the
/// edges. If [currentValue] is `null` (no data), the marker is hidden but
/// the zones are still drawn so users see the safe range as reference.
class VitalSafeRangeBar extends StatelessWidget {
  const VitalSafeRangeBar({
    super.key,
    required this.range,
    required this.currentValue,
    this.title = 'Khoảng an toàn',
  });

  final VitalSafeRange range;
  final double? currentValue;
  final String title;

  /// Returns 5 weights summing to a non-zero positive total, where each
  /// weight is the relative axis-distance covered by that zone. Some vitals
  /// (e.g. SpO₂) have collapsed upper zones — those receive weight 0.
  List<double> _zoneWeights() {
    return [
      (range.criticalLow - range.axisMin).clamp(0, double.infinity),
      (range.normalLow - range.criticalLow).clamp(0, double.infinity),
      (range.normalHigh - range.normalLow).clamp(0, double.infinity),
      (range.criticalHigh - range.normalHigh).clamp(0, double.infinity),
      (range.axisMax - range.criticalHigh).clamp(0, double.infinity),
    ];
  }

  /// 0..1 marker position along the bar. Clamped so out-of-axis values still
  /// render at the corresponding edge.
  double _markerFraction() {
    final value = currentValue;
    if (value == null) return 0;
    final span = range.axisMax - range.axisMin;
    if (span <= 0) return 0;
    return ((value - range.axisMin) / span).clamp(0.0, 1.0);
  }

  String _zoneLabel() {
    final value = currentValue;
    if (value == null) return '';
    if (value < range.criticalLow) return 'Quá thấp';
    if (value < range.normalLow) return 'Hơi thấp';
    if (value <= range.normalHigh) return 'Trong khoảng an toàn';
    if (value <= range.criticalHigh) return 'Hơi cao';
    return 'Vượt ngưỡng';
  }

  Color _zoneLabelColor() {
    final value = currentValue;
    if (value == null) return AppColors.textSecondary;
    if (value < range.criticalLow || value > range.criticalHigh) {
      return AppColors.critical;
    }
    if (value < range.normalLow || value > range.normalHigh) {
      return AppColors.warning;
    }
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final weights = _zoneWeights();
    final markerFraction = _markerFraction();
    final zoneLabel = _zoneLabel();
    final zoneColor = _zoneLabelColor();
    final hasMarker = currentValue != null;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
              ),
              if (hasMarker)
                Text(
                  zoneLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: zoneColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.gapMd),
          LayoutBuilder(
            builder: (context, constraints) {
              return _Gauge(
                weights: weights,
                markerFraction: markerFraction,
                hasMarker: hasMarker,
                width: constraints.maxWidth,
              );
            },
          ),
          SizedBox(height: AppSpacing.gapMd),
          _AxisLabels(range: range),
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.weights,
    required this.markerFraction,
    required this.hasMarker,
    required this.width,
  });

  final List<double> weights;
  final double markerFraction;
  final bool hasMarker;
  final double width;

  static const _zoneColors = <Color>[
    AppColors.critical,
    AppColors.warning,
    AppColors.success,
    AppColors.warning,
    AppColors.critical,
  ];

  @override
  Widget build(BuildContext context) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return SizedBox(width: width, height: 12);
    }

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.radiusSm),
            child: Row(
              children: List.generate(weights.length, (i) {
                final w = weights[i];
                if (w <= 0) return const SizedBox.shrink();
                return Expanded(
                  flex: (w * 1000).round(),
                  child: Container(
                    height: 12,
                    color: _zoneColors[i].withValues(alpha: 0.85),
                  ),
                );
              }),
            ),
          ),
          if (hasMarker)
            Positioned(
              left: (markerFraction * width) - 8,
              top: -6,
              child: const _Marker(),
            ),
        ],
      ),
    );
  }
}

/// Diamond marker drawn above the gauge to indicate current value.
class _Marker extends StatelessWidget {
  const _Marker();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            border: Border.all(color: AppColors.bgSurface, width: 2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tick labels under the gauge: critical-low / normal-low / normal-high /
/// critical-high. Each label is positioned at its **true axis fraction** so
/// the labels line up with the corresponding zone boundaries on the gauge.
///
/// Implementation: `Stack` with `Positioned(left: fraction * width - half)`,
/// each label given a fixed-width centered cell so visual centering stays
/// stable across 2-, 3- and 4-character numeric values (e.g. "60" vs "37.8").
class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.range});
  final VitalSafeRange range;

  static const double _labelCellWidth = 36;

  String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  double _fraction(double value) {
    final span = range.axisMax - range.axisMin;
    if (span <= 0) return 0;
    return ((value - range.axisMin) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final hasUpperWarning = range.criticalHigh > range.normalHigh;

    final ticks = <_TickSpec>[
      _TickSpec(
        fraction: _fraction(range.criticalLow),
        label: _format(range.criticalLow),
        color: AppColors.textSecondary,
        weight: FontWeight.w600,
      ),
      _TickSpec(
        fraction: _fraction(range.normalLow),
        label: _format(range.normalLow),
        color: AppColors.success,
        weight: FontWeight.w700,
      ),
      _TickSpec(
        fraction: _fraction(range.normalHigh),
        label: _format(range.normalHigh),
        color: AppColors.success,
        weight: FontWeight.w700,
      ),
      if (hasUpperWarning)
        _TickSpec(
          fraction: _fraction(range.criticalHigh),
          label: _format(range.criticalHigh),
          color: AppColors.textSecondary,
          weight: FontWeight.w600,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          width: width,
          height: 18,
          child: Stack(
            clipBehavior: Clip.none,
            children: ticks.map((tick) {
              final centerX = tick.fraction * width;
              return Positioned(
                left: centerX - _labelCellWidth / 2,
                child: SizedBox(
                  width: _labelCellWidth,
                  child: Text(
                    tick.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: tick.color,
                      fontWeight: tick.weight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _TickSpec {
  const _TickSpec({
    required this.fraction,
    required this.label,
    required this.color,
    required this.weight,
  });
  final double fraction;
  final String label;
  final Color color;
  final FontWeight weight;
}
