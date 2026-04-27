import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../../../shared/presentation/feedback/inline_error_block.dart';
import '../../../../shared/presentation/feedback/inline_status_banner.dart';
import '../../providers/risk_report_provider.dart';
import '../widgets/factor_contribution_section.dart';
import '../widgets/first_aid_action_card.dart';
import '../widgets/medical_disclaimer_card.dart';
import '../widgets/recommendation_checklist_card.dart';
import '../widgets/related_drilldown_section.dart';
import '../widgets/risk_detail_summary_card.dart';
import '../widgets/supporting_metrics_snapshot_card.dart';
import '../widgets/xai_narrative_card.dart';
import '../../../profile/providers/clinician_audience_provider.dart';

class RiskReportDetailScreen extends StatefulWidget {
  final int reportId;
  final String? profileId;

  const RiskReportDetailScreen({
    super.key,
    required this.reportId,
    this.profileId,
  });

  @override
  State<RiskReportDetailScreen> createState() => _RiskReportDetailScreenState();
}

class _RiskReportDetailScreenState extends State<RiskReportDetailScreen> {
  /// Phase 8 / slice 4a: resolve the audience query parameter from
  /// the persistent toggle, falling back to ``null`` when the
  /// provider isn't injected (e.g. older widget tests that don't yet
  /// know about the new dependency). Defensive so this slice doesn't
  /// require a same-PR migration of every existing test fixture.
  String? _resolveAudience() {
    try {
      return context
          .read<ClinicianAudienceProvider>()
          .audienceQueryValue;
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiskReportProvider>().fetchReportDetail(
        widget.reportId,
        widget.profileId,
        audience: _resolveAudience(),
      );
    });
  }

  Future<void> _onRefresh() async {
    await context.read<RiskReportProvider>().fetchReportDetail(
      widget.reportId,
      widget.profileId,
      audience: _resolveAudience(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLinkedProfile =
        widget.profileId != null && widget.profileId != "self";
    final provider = context.watch<RiskReportProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giải thích báo cáo rủi ro',
              style: AppTextStyles.sectionTitle,
            ),
            if (isLinkedProfile)
              Text(
                'Hồ sơ người thân',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(RiskReportProvider provider) {
    if (provider.isInitialLoading && provider.reportDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.reportDetail == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.gapLg),
        child: InlineErrorBlock(message: provider.error!, onRetry: _onRefresh),
      );
    }

    final detail = provider.reportDetail;
    if (detail == null) {
      return const Center(child: Text('Chưa có dữ liệu đánh giá chi tiết'));
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.gapLg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (provider.hasStaleContent) ...[
                  InlineStatusBanner.warning(
                    message:
                        'Chi tiết này được tính từ dữ liệu cũ. Hãy đối chiếu với chỉ số hiện tại.',
                  ),
                  const SizedBox(height: AppSpacing.gapLg),
                ],
                if (provider.isRefreshing) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.gapLg),
                ],
                RiskDetailSummaryCard(detail: detail),
                const SizedBox(height: AppSpacing.gapLg),
                XaiNarrativeCard(
                  explanation: detail.xaiExplanation,
                  aiExplanation: detail.aiExplanation.isNotEmpty
                      ? detail.aiExplanation
                      : null,
                ),
                const SizedBox(height: AppSpacing.gapLg),
                FirstAidActionCard(
                  level: detail.level,
                  onMeasureAgain: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.vitalDetail,
                      arguments: {
                        'vitalType': 'hr',
                        'profileId': widget.profileId,
                      },
                    );
                  },
                  onContactFamily: () {
                    Navigator.pushNamed(context, AppRouter.familyDashboard);
                  },
                ),
                const SizedBox(height: AppSpacing.gapLg),
                FactorContributionSection(
                  breakdown: detail.breakdown,
                  onFactorTap: (routeTarget) {
                    if (routeTarget.startsWith('vital_')) {
                      final type = routeTarget.split('_')[1];
                      Navigator.pushNamed(
                        context,
                        AppRouter.vitalDetail,
                        arguments: {
                          'vitalType': type,
                          'profileId': widget.profileId,
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.gapLg),
                SupportingMetricsSnapshotCard(snapshot: detail.snapshot),
                const SizedBox(height: AppSpacing.gapLg),
                RecommendationChecklistCard(
                  recommendations:
                      detail.aiExplanation.recommendedActions.isNotEmpty
                      ? detail.aiExplanation.recommendedActions
                      : detail.recommendations,
                ),
                const SizedBox(height: AppSpacing.gapLg),
                RelatedDrilldownSection(
                  onVitalTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.vitalDetail,
                      arguments: {
                        'vitalType': 'hr',
                        'profileId': widget.profileId,
                      },
                    );
                  },
                  onSleepTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.sleepReport,
                      arguments: {'profileId': widget.profileId},
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.gapLg),
                const MedicalDisclaimerCard(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
