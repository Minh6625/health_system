import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/widgets/empty_sleep_view.dart';
import 'package:healthguard/features/sleep_analysis/widgets/no_data_tonight_view.dart';
import 'package:healthguard/features/sleep_analysis/widgets/phase_composition_chart.dart';
import 'package:healthguard/features/sleep_analysis/widgets/shimmer_sleep_loading.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_hero_card.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_timeline_bar.dart';
import 'package:healthguard/features/sleep_analysis/widgets/starry_background.dart';
import 'package:provider/provider.dart';

class SleepReportScreen extends StatefulWidget {
  final String? profileId;
  final DateTime? date;

  const SleepReportScreen({
    super.key,
    this.profileId,
    this.date,
  });

  @override
  State<SleepReportScreen> createState() => _SleepReportScreenState();
}

class _SleepReportScreenState extends State<SleepReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SleepProvider>();
      provider.loadAll(patientId: widget.profileId);
      if (widget.date != null) {
        provider.selectDate(widget.date!);
      }
    });
  }

  Future<void> _onOpenFullCalendar(BuildContext context, SleepProvider provider) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.selectedDate,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF071220),
      body: StarryBackground(
        child: SafeArea(
          child: Consumer<SleepProvider>(
            builder: (context, provider, _) {
              return RefreshIndicator(
                onRefresh: () => provider.fetchLatestSleep(patientId: widget.profileId),
                color: const Color(0xFF48D6FF),
                backgroundColor: const Color(0xFF10233F),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(context),
                    _buildBody(context, provider),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF071220),
      foregroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      title: const Text('Báo cáo Giấc ngủ', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => context.read<SleepProvider>().fetchLatestSleep(patientId: widget.profileId),
          tooltip: 'Làm mới',
        ),
        // Settings only for self-profile
        if (widget.profileId == null)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/sleep-settings');
            },
            tooltip: 'Cài đặt',
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SleepProvider provider) {
    if (provider.isLoading) {
      return const SliverFillRemaining(hasScrollBody: false, child: ShimmerSleepLoading());
    }
    if (provider.hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorView(
          message: provider.errorMessage ?? 'Lỗi',
          onRetry: () => provider.loadAll(patientId: widget.profileId),
        ),
      );
    }
    if (provider.isNoDataYet) {
      return const SliverFillRemaining(hasScrollBody: false, child: NoDataTonightView());
    }
    if (provider.isEmpty) {
      return const SliverFillRemaining(hasScrollBody: false, child: EmptySleepView());
    }

    final session = provider.selectedSession;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (provider.dateLoading)
            _DateLoadingShimmer()
          else
            SleepHeroCard(
              session: session,
              selectedDate: provider.selectedDate,
              onDateSelected: (day) => provider.selectDate(day),
              onCalendarTap: () => _onOpenFullCalendar(context, provider),
            ),
          const SizedBox(height: 24),
          
          if (session != null) ...[
            // Preview of timeline & phases
            const Text('Dữ liệu đêm', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SleepTimelineBar(session: session),
            const SizedBox(height: 20),
            PhaseCompositionChart(session: session),
            const SizedBox(height: 32),
            
            // CTA Buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context, 
                    '/sleep-detail', 
                    arguments: {'profileId': widget.profileId, 'date': provider.selectedDate}
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48D6FF),
                  foregroundColor: const Color(0xFF07162B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Xem chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context, 
                  '/sleep-history',
                  arguments: {'profileId': widget.profileId}
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF48D6FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Lịch sử giấc ngủ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

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
        child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Color(0xFF48D6FF), strokeWidth: 2.5)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFF5B7FA6), size: 64),
          const SizedBox(height: 20),
          Text(message, style: const TextStyle(color: Color(0xFF90A6C3))),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
