import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/theme/app_colors.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text_styles.dart';
import '../../../../shared/presentation/feedback/inline_error_block.dart';
import '../../domain/entities/risk_history_entity.dart';
import '../../providers/risk_history_provider.dart';
import '../widgets/compare_insight_card.dart';
import '../widgets/pagination_footer.dart';
import '../widgets/range_filter_chips.dart';
import '../widgets/risk_history_item_card.dart';
import '../widgets/risk_trend_summary_card.dart';

class RiskHistoryScreen extends StatefulWidget {
  final String? profileId;

  const RiskHistoryScreen({super.key, this.profileId});

  @override
  State<RiskHistoryScreen> createState() => _RiskHistoryScreenState();
}

class _RiskHistoryScreenState extends State<RiskHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiskHistoryProvider>().fetchHistory(
        profileId: widget.profileId ?? 'self',
        refresh: true,
      );
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<RiskHistoryProvider>().loadMore(
          widget.profileId ?? 'self',
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await context.read<RiskHistoryProvider>().fetchHistory(
      profileId: widget.profileId ?? 'self',
      refresh: true,
    );
  }

  // Helper to group items by month and year
  Map<String, List<RiskHistoryItemEntity>> _groupItemsByMonth(
    List<RiskHistoryItemEntity> items,
  ) {
    final Map<String, List<RiskHistoryItemEntity>> grouped = {};
    for (var item in items) {
      final key = DateFormat('MM/yyyy').format(item.analyzedAt);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isLinkedProfile =
        widget.profileId != null && widget.profileId != "self";
    final provider = context.watch<RiskHistoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch sử đánh giá rủi ro',
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

  Widget _buildBody(RiskHistoryProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.gapLg),
        child: InlineErrorBlock(message: provider.error!, onRetry: _onRefresh),
      );
    }

    final groupedItems = _groupItemsByMonth(provider.items);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.gapMd,
                left: AppSpacing.gapLg,
                right: AppSpacing.gapLg,
              ),
              child: RangeFilterChips(
                currentRange: provider.currentRange,
                onRangeSelected: (range) =>
                    provider.changeRange(widget.profileId ?? 'self', range),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.gapLg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (provider.summary != null) ...[
                  RiskTrendSummaryCard(summary: provider.summary!),
                  const SizedBox(height: AppSpacing.gapLg),
                  CompareInsightCard(
                    delta: provider.summary!.deltaVsPreviousPeriod,
                  ),
                  const SizedBox(height: AppSpacing.gapLg),
                ],
                if (provider.items.isEmpty && !provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text('Chưa có lịch sử')),
                  ),
                ...groupedItems.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.gapMd,
                          top: AppSpacing.gapMd,
                        ),
                        child: Text(
                          'Tháng ${entry.key}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      ...entry.value.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.gapSm,
                          ),
                          child: RiskHistoryItemCard(
                            item: item,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.riskReportDetail,
                                arguments: {
                                  'reportId': item.reportId,
                                  'profileId': widget.profileId,
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                PaginationFooter(
                  isLoadingMore: provider.isLoadingMore,
                  hasMore: provider.hasMore,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
