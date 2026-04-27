import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/risk_report_detail_entity.dart';

/// Phase 8 slice 4b — clinician-only SHAP waterfall screen.
///
/// Reachable from [RiskReportDetailScreen] when:
///
/// 1. The "Chế độ chuyên môn" toggle is on, AND
/// 2. The current detail entity carries a populated [ShapWaterfall]
///    (i.e. the clinician audience response succeeded — rule-based
///    fallback rows return ``available=false`` and the link is
///    suppressed).
///
/// Renders a horizontal bar chart of per-feature SHAP contributions,
/// sorted by absolute magnitude, with positive bars (push toward
/// higher risk) coloured in the error palette and negative bars
/// (protective) in the success palette. Each bar shows the feature
/// name, signed value, and a magnitude bar. Plus a header with the
/// base value + total contribution, and a "Copy request_id" button
/// at the bottom for log correlation.
class RiskShapDetailScreen extends StatelessWidget {
  /// The clinician detail entity with [RiskReportDetailEntity.shapDetails]
  /// already populated. Caller guarantees non-null + ``hasValues``.
  final RiskReportDetailEntity detail;

  const RiskShapDetailScreen({super.key, required this.detail});

  static const String routeName = '/risk-report/shap-detail';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shap = detail.shapDetails;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết SHAP'),
      ),
      body: SafeArea(
        child: shap == null || !shap.hasValues
            ? _UnavailableState(theme: theme)
            : _ShapBody(detail: detail, shap: shap),
      ),
    );
  }
}

class _ShapBody extends StatelessWidget {
  final RiskReportDetailEntity detail;
  final ShapWaterfall shap;
  const _ShapBody({required this.detail, required this.shap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sort by absolute magnitude (largest first) — same convention
    // every SHAP visualisation library uses.
    final sorted = [...shap.values]
      ..sort((a, b) => b.impact.compareTo(a.impact));
    // Cap at 20 bars to keep the screen scannable on phones; backend
    // already limits this server-side but defend just in case.
    final visible = sorted.take(20).toList();
    final maxImpact = visible.isEmpty
        ? 1.0
        : visible.map((c) => c.impact).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Header(detail: detail, shap: shap, theme: theme),
        const SizedBox(height: 16),
        Text(
          'Đóng góp của từng đặc trưng',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Sắp xếp theo độ lớn ảnh hưởng. Bar đỏ làm tăng nguy cơ, '
          'bar xanh là yếu tố bảo vệ.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final c in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShapBar(
              contribution: c, maxImpact: maxImpact, theme: theme,
            ),
          ),
        const SizedBox(height: 8),
        if (detail.modelRequestId != null)
          _RequestIdRow(requestId: detail.modelRequestId!, theme: theme),
        const SizedBox(height: 16),
        _DisclaimerCard(theme: theme),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final RiskReportDetailEntity detail;
  final ShapWaterfall shap;
  final ThemeData theme;
  const _Header({
    required this.detail,
    required this.shap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Báo cáo #${detail.reportId}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Base value',
                  value: shap.baseValue.toStringAsFixed(3),
                  theme: theme,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Tổng đóng góp',
                  value: (shap.totalContribution >= 0 ? '+' : '') +
                      shap.totalContribution.toStringAsFixed(3),
                  theme: theme,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Số đặc trưng',
                  value: shap.values.length.toString(),
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  const _Metric({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ShapBar extends StatelessWidget {
  final ShapContribution contribution;
  final double maxImpact;
  final ThemeData theme;
  const _ShapBar({
    required this.contribution,
    required this.maxImpact,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxImpact == 0 ? 0.0 : contribution.impact / maxImpact;
    final colour = contribution.isProtective
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    final sign = contribution.shapValue >= 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                contribution.feature,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$sign${contribution.shapValue.toStringAsFixed(3)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colour,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            backgroundColor: colour.withValues(alpha: 0.12),
            color: colour,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _RequestIdRow extends StatelessWidget {
  final String requestId;
  final ThemeData theme;
  const _RequestIdRow({required this.requestId, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.fingerprint,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mã yêu cầu mô hình',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    requestId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sao chép',
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: requestId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã sao chép $requestId'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  final ThemeData theme;
  const _UnavailableState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Không có SHAP cho báo cáo này',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Báo cáo này được tạo bằng nhánh dự đoán dự phòng, không có '
            'giá trị SHAP. Hãy kiểm tra báo cáo khác.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final ThemeData theme;
  const _DisclaimerCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đây là dữ liệu chuyên môn dùng để giải thích mô hình AI, '
              'không phải chẩn đoán y khoa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
