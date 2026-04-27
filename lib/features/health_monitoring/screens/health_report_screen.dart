import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/routes/app_router.dart';
import '../../../shared/presentation/theme/app_colors.dart';
import '../../../shared/presentation/theme/app_radii.dart';
import '../../../shared/presentation/theme/app_spacing.dart';
import '../../../shared/presentation/theme/app_text_styles.dart';
import '../models/health_report.dart';
import '../providers/health_report_provider.dart';
import '../widgets/error_view.dart';

/// 24-hour aggregated health report screen. Wired to `/metrics/health-report`
/// (vitals 24h avg + latest risk + AI health score). Pull-to-refresh.
class HealthReportScreen extends StatefulWidget {
  const HealthReportScreen({super.key, this.profileId});

  final String? profileId;

  @override
  State<HealthReportScreen> createState() => _HealthReportScreenState();
}

class _HealthReportScreenState extends State<HealthReportScreen> {
  late final HealthReportProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = HealthReportProvider(profileId: widget.profileId);
    _provider.load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            title: const Text('Báo cáo sức khoẻ'),
            backgroundColor: AppColors.bgSurface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            centerTitle: true,
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _provider.refresh,
              child: _buildBody(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_provider.state) {
      case HealthReportUIState.initial:
      case HealthReportUIState.loading:
        return const Center(child: CircularProgressIndicator());
      case HealthReportUIState.error:
        return ErrorView(
          message:
              _provider.error ??
              'Không thể tải báo cáo.\nVui lòng kiểm tra kết nối.',
          onRetry: _provider.load,
        );
      case HealthReportUIState.success:
        final report = _provider.report;
        if (report == null) {
          return const Center(
            child: Text('Chưa có dữ liệu báo cáo trong 24h qua.'),
          );
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenHorizontalPadding.copyWith(
            top: AppSpacing.sectionGapMd,
            bottom: AppSpacing.sectionGapXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report.isStale) _StaleBadge(),
              if (report.isStale)
                const SizedBox(height: AppSpacing.sectionGapMd),
              _HealthScoreHero(report: report),
              const SizedBox(height: AppSpacing.sectionGapLg),
              _SectionHeader(title: 'Trung bình 24 giờ qua'),
              const SizedBox(height: AppSpacing.gapMd),
              _VitalsAvgGrid(vitals: report.vitals24hAvg),
              const SizedBox(height: AppSpacing.sectionGapLg),
              _SectionHeader(title: 'Đánh giá rủi ro'),
              const SizedBox(height: AppSpacing.gapMd),
              _RiskInsightCard(
                report: report,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRouter.riskReport,
                  arguments: {'profileId': widget.profileId},
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGapLg),
              if (report.lastUpdated != null)
                _LastUpdatedRow(timestamp: report.lastUpdated!),
            ],
          ),
        );
    }
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.sectionTitle);
  }
}

// ── Stale badge ─────────────────────────────────────────────────────────────

class _StaleBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gapMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppStateColors.warningBg,
        borderRadius: BorderRadius.circular(AppRadii.radiusSm),
        border: Border.all(color: const Color(0xFFF8CF9B)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.gapSm),
          Expanded(
            child: Text(
              'Dữ liệu chưa cập nhật trong 24h qua. Đeo đồng hồ để có báo cáo chính xác.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Health score hero card ──────────────────────────────────────────────────

class _HealthScoreHero extends StatelessWidget {
  const _HealthScoreHero({required this.report});
  final HealthReport report;

  Color _levelColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'critical':
      case 'high':
        return AppColors.critical;
      case 'medium':
      case 'moderate':
        return AppColors.warning;
      case 'low':
      case 'good':
      case 'normal':
        return AppColors.success;
      default:
        return AppColors.brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = report.healthScore;
    final level = report.healthLevel;
    final summary = report.healthSummary;
    final accent = _levelColor(level);

    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.92), accent.withValues(alpha: 0.7)],
        ),
        borderRadius: AppRadii.cardRadius,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Text(
                'Điểm sức khoẻ tổng hợp',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score != null ? score.toStringAsFixed(0) : '--',
                style: AppTextStyles.vitalValue.copyWith(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ 100',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          if (level != null && level.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gapXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: AppRadii.pillRadius,
              ),
              child: Text(
                level.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          if (summary != null && summary.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gapMd),
            Text(
              summary,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Vitals 24h average grid ─────────────────────────────────────────────────

class _VitalsAvgGrid extends StatelessWidget {
  const _VitalsAvgGrid({required this.vitals});
  final Map<String, num?> vitals;

  @override
  Widget build(BuildContext context) {
    final hr = vitals['heart_rate'];
    final spo2 = vitals['spo2'];
    final temp = vitals['temperature'];
    final rr = vitals['respiratory_rate'];
    final bpSys = vitals['blood_pressure_sys'];
    final bpDia = vitals['blood_pressure_dia'];

    final cards = <_VitalAvgCardData>[
      _VitalAvgCardData(
        icon: Icons.favorite,
        label: 'Nhịp tim',
        value: hr != null ? hr.toStringAsFixed(0) : '--',
        unit: 'bpm',
        color: Colors.red,
      ),
      _VitalAvgCardData(
        icon: Icons.water_drop,
        label: 'SpO₂',
        value: spo2 != null ? spo2.toStringAsFixed(0) : '--',
        unit: '%',
        color: Colors.blue,
      ),
      _VitalAvgCardData(
        icon: Icons.monitor_heart_outlined,
        label: 'Huyết áp',
        value: (bpSys != null && bpDia != null)
            ? '${bpSys.toStringAsFixed(0)}/${bpDia.toStringAsFixed(0)}'
            : '--',
        unit: 'mmHg',
        color: Colors.purple,
      ),
      _VitalAvgCardData(
        icon: Icons.thermostat,
        label: 'Nhiệt độ',
        value: temp != null ? temp.toStringAsFixed(1) : '--',
        unit: '°C',
        color: Colors.orange,
      ),
      _VitalAvgCardData(
        icon: Icons.air,
        label: 'Nhịp thở',
        value: rr != null ? rr.toStringAsFixed(0) : '--',
        unit: 'lần/phút',
        color: Colors.teal,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.gapMd,
        crossAxisSpacing: AppSpacing.gapMd,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, index) => _VitalAvgCard(data: cards[index]),
    );
  }
}

class _VitalAvgCardData {
  const _VitalAvgCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final MaterialColor color;
}

class _VitalAvgCard extends StatelessWidget {
  const _VitalAvgCard({required this.data});
  final _VitalAvgCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: AppColors.strokeSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: data.color.shade50,
                  borderRadius: BorderRadius.circular(AppRadii.radiusSm),
                ),
                child: Icon(data.icon, size: 16, color: data.color.shade700),
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: Text(
                  data.label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  data.value,
                  style: AppTextStyles.vitalValue.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                data.unit,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Risk insight card ───────────────────────────────────────────────────────

class _RiskInsightCard extends StatelessWidget {
  const _RiskInsightCard({required this.report, required this.onTap});
  final HealthReport report;
  final VoidCallback onTap;

  Color _riskColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'high':
      case 'critical':
        return AppColors.critical;
      case 'medium':
      case 'moderate':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = report.latestRiskScore;
    final level = report.riskLevel;
    final type = report.riskType;
    final accent = _riskColor(level);

    return Material(
      color: AppColors.bgSurface,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        borderRadius: AppRadii.cardRadius,
        onTap: onTap,
        child: Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.strokeSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield, color: accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score != null
                          ? 'Điểm rủi ro: ${score.toStringAsFixed(1)}'
                          : 'Chưa có đánh giá',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (level != null && level.isNotEmpty) level,
                        if (type != null && type.isNotEmpty) type,
                      ].join(' • '),
                      style: AppTextStyles.caption.copyWith(color: accent),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Last updated footer ─────────────────────────────────────────────────────

class _LastUpdatedRow extends StatelessWidget {
  const _LastUpdatedRow({required this.timestamp});
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('HH:mm dd/MM/yyyy').format(timestamp);
    return Center(
      child: Text(
        'Cập nhật lần cuối: $formatted',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
