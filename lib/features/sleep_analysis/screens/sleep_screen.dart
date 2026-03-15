import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/widgets/empty_sleep_view.dart';
import 'package:healthguard/features/sleep_analysis/widgets/info_tooltip_icon.dart';
import 'package:healthguard/features/sleep_analysis/widgets/metric_tile.dart';
import 'package:healthguard/features/sleep_analysis/widgets/phase_composition_chart.dart';
import 'package:healthguard/features/sleep_analysis/widgets/shimmer_sleep_loading.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_hero_card.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_timeline_bar.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_trend_chart.dart';
import 'package:provider/provider.dart';
import '../../family/widgets/profile_switcher.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SleepProvider>().loadAll();
    });
  }

  // ── Full Calendar Date Picker ────────────────────────────────────────────

  Future<void> _onOpenFullCalendar(
    BuildContext context,
    SleepProvider provider,
  ) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today, // no future dates
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF48D6FF),
            onPrimary: Color(0xFF07162B),
            surface: Color(0xFF0D1E38),
            onSurface: Colors.white,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF0D1E38),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && context.mounted) {
      provider.selectDate(picked);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07162B),
      body: SafeArea(
        child: Consumer<SleepProvider>(
          builder: (context, provider, _) {
            return NestedScrollView(
              headerSliverBuilder: (ctx, _) => [_buildAppBar(context)],
              body: _buildBody(context, provider),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF07162B),
      foregroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      floating: false,
      title: const Text(
        'Giấc Ngủ',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ProfileSwitcher(
              onProfileChanged: () {
                context.read<SleepProvider>().fetchLatestSleep();
              },
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            context.read<SleepProvider>().fetchLatestSleep();
          },
          tooltip: 'Làm mới',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SleepProvider provider) {
    // ── Loading ──────────────────────────────────────────────────────────
    if (provider.isLoading) {
      return const ShimmerSleepLoading();
    }

    // ── Error ────────────────────────────────────────────────────────────
    if (provider.hasError) {
      return _ErrorView(
        message: provider.errorMessage ?? 'Đã xảy ra lỗi',
        onRetry: () => provider.loadAll(),
      );
    }

    // ── Empty ────────────────────────────────────────────────────────────
    if (provider.isEmpty) {
      return const EmptySleepView();
    }

    // ── Success ──────────────────────────────────────────────────────────
    final session = provider.selectedSession;
    final history = provider.historyList;

    return RefreshIndicator(
      onRefresh: () => provider.fetchLatestSleep(),
      color: const Color(0xFF48D6FF),
      backgroundColor: const Color(0xFF10233F),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Hero Card ─────────────────────────────────────────────
                if (provider.dateLoading)
                  _DateLoadingShimmer()
                else
                  SleepHeroCard(
                    session: session,
                    selectedDate: provider.selectedDate,
                    onDateSelected: (day) => provider.selectDate(day),
                    onCalendarTap: () => _onOpenFullCalendar(context, provider),
                  ),
                const SizedBox(height: 20),

                // ── ExpansionTile: Detail Analysis ────────────────────────
                _buildDetailExpansionTile(session, history, provider),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailExpansionTile(
    SleepSession? session,
    List<SleepSession> history,
    SleepProvider provider,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1E38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x264B5E82), width: 1),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: const Color(0xFF48D6FF),
          collapsedIconColor: const Color(0xFF5B7FA6),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0x1A48D6FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF48D6FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Xem chi tiết phân tích',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            const SizedBox(height: 8),

            // ── Timeline Bar ────────────────────────────────────────────
            if (session != null) ...[
              _SectionHeader(
                title: 'Thời gian phân bổ',
                tooltip: const InfoTooltipIcon(topic: SleepInfoTopic.phases),
              ),
              const SizedBox(height: 10),
              SleepTimelineBar(session: session)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 80.ms)
                  .slideY(
                    begin: 0.06,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 20),
            ],

            // ── Phase Composition (Donut) ───────────────────────────────
            if (session != null && session.phases != null) ...[
              _SectionHeader(title: 'Cơ cấu giấc ngủ'),
              const SizedBox(height: 10),
              PhaseCompositionChart(session: session)
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 140.ms)
                  .scale(
                    begin: const Offset(0.96, 0.96),
                    end: const Offset(1, 1),
                    duration: 450.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 20),
            ],

            // ── Metrics ─────────────────────────────────────────────────
            if (session != null) ...[
              _SectionHeader(title: 'Chi tiết chỉ số'),
              const SizedBox(height: 10),
              _buildMetrics(
                session,
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 20),
            ],

            // ── Trend Chart ─────────────────────────────────────────────
            _SectionHeader(
              title: 'Xu hướng 7 ngày',
              tooltip: const InfoTooltipIcon(topic: SleepInfoTopic.trend),
            ),
            const SizedBox(height: 10),
            SleepTrendChart(
              historyList: history.toList(),
              highlightedDate: session?.endTime,
              onSessionTapped: provider.selectHistorySession,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(SleepSession session) {
    return Column(
      children: [
        const Divider(color: Color(0x224B5E82), height: 1),
        MetricTile(
          icon: Icons.hotel_rounded,
          iconColor: const Color(0xFF48A9D6),
          label: 'Thời gian trên giường',
          value: session.inBedText,
        ),
        const Divider(color: Color(0x224B5E82), height: 1),
        MetricTile(
          icon: Icons.nightlight_rounded,
          iconColor: const Color(0xFF9C6ADE),
          label: 'Thời gian thức',
          value: session.awakeText,
        ),
        const Divider(color: Color(0x224B5E82), height: 1),
        MetricTile(
          icon: Icons.alarm_rounded,
          iconColor: const Color(0xFFFFC400),
          label: 'Số lần thức giấc',
          value: '${session.wakeCount}',
          unit: 'lần',
        ),
        const Divider(color: Color(0x224B5E82), height: 1),
        MetricTile(
          icon: Icons.percent_rounded,
          iconColor: const Color(0xFF4CAF50),
          label: 'Hiệu quả giấc ngủ',
          value: '${(session.efficiencyRatio * 100).toStringAsFixed(0)}%',
        ),
        const Divider(color: Color(0x224B5E82), height: 1),
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? tooltip;

  const _SectionHeader({required this.title, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF48D6FF),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (tooltip != null) ...[const SizedBox(width: 6), tooltip!],
      ],
    );
  }
}

// ── Date Loading Shimmer ──────────────────────────────────────────────────────

class _DateLoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E38),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x332C4367), width: 1),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: Color(0xFF48D6FF),
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFF5B7FA6),
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF90A6C3),
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10233F),
                foregroundColor: const Color(0xFF48D6FF),
                side: const BorderSide(color: Color(0x6648D6FF)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
