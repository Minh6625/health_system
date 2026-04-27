import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_radii.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../../../shared/presentation/feedback/inline_error_block.dart';
import '../../../../shared/presentation/feedback/inline_status_banner.dart';
import '../../providers/risk_report_provider.dart';
import '../widgets/medical_disclaimer_card.dart';
import '../widgets/recommendation_preview_card.dart';
import '../widgets/risk_quick_explanation_card.dart';
import '../widgets/risk_score_hero_card.dart';
import '../widgets/risk_trend_preview_card.dart';
import '../widgets/top_factor_chips_section.dart';

class RiskReportScreen extends StatefulWidget {
  final String? profileId;

  const RiskReportScreen({super.key, this.profileId});

  @override
  State<RiskReportScreen> createState() => _RiskReportScreenState();
}

class _RiskReportScreenState extends State<RiskReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiskReportProvider>().fetchLatestReport(widget.profileId);
    });
  }

  Future<void> _onRefresh() async {
    await context.read<RiskReportProvider>().fetchLatestReport(
      widget.profileId,
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
              'Báo cáo rủi ro sức khỏe',
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
    if (provider.isInitialLoading &&
        provider.report == null &&
        !provider.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.report == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.gapLg),
        child: InlineErrorBlock(message: provider.error!, onRetry: _onRefresh),
      );
    }

    final report = provider.report;
    if (provider.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gapLg),
          child: Text(
            provider.emptyMessage ??
                'Chưa có báo cáo rủi ro. Hãy đeo thiết bị thêm vài giờ để hệ thống tạo báo cáo đầu tiên.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (report == null) {
      return const SizedBox.shrink();
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
                        'Báo cáo này được tạo từ dữ liệu cũ. Hãy kiểm tra lại chỉ số gần nhất.',
                  ),
                  const SizedBox(height: AppSpacing.gapLg),
                ],
                if (provider.isRefreshing) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.gapLg),
                ],
                RiskScoreHeroCard(report: report),
                const SizedBox(height: AppSpacing.gapLg),
                RiskQuickExplanationCard(
                  summary: report.summary,
                  topFactors: report.topFactors,
                ),
                const SizedBox(height: AppSpacing.gapLg),
                TopFactorChipsSection(factors: report.topFactors),
                const SizedBox(height: AppSpacing.gapLg),
                RiskTrendPreviewCard(
                  trend7d: report.healthTrend7d,
                  healthDelta: report.healthDelta,
                ),
                const SizedBox(height: AppSpacing.gapLg),
                RecommendationPreviewCard(
                  recommendations: report.recommendationPreview,
                ),
                const SizedBox(height: AppSpacing.gapLg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRouter.riskReportDetail,
                          arguments: {
                            'reportId': report.reportId,
                            'profileId': widget.profileId,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.gapLg,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.cardRadius,
                        ),
                      ),
                      child: Text(
                        'Xem giải thích AI',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.bgSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gapMd),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRouter.riskHistory,
                          arguments: {'profileId': widget.profileId},
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.gapLg,
                        ),
                        side: const BorderSide(color: AppColors.brandPrimary),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.cardRadius,
                        ),
                      ),
                      child: Text(
                        'Xem lịch sử',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
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
