import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/models/sleep_session.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/widgets/metric_tile.dart';
import 'package:healthguard/features/sleep_analysis/widgets/phase_composition_chart.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_timeline_bar.dart';
import 'package:healthguard/features/sleep_analysis/widgets/starry_background.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:provider/provider.dart';

class SleepDetailScreen extends StatefulWidget {
  final String? profileId;
  final DateTime? date;

  const SleepDetailScreen({super.key, this.profileId, this.date});

  @override
  State<SleepDetailScreen> createState() => _SleepDetailScreenState();
}

class _SleepDetailScreenState extends State<SleepDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SleepProvider>();
      provider.setPatient(widget.profileId);
      if (widget.date != null) {
        provider.selectDate(widget.date!);
      } else {
        provider.loadAll(patientId: widget.profileId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF071220),
      appBar: AppBar(
        title: const Text('Chi tiết giấc ngủ'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StarryBackground(
        child: SafeArea(
          child: Consumer<SleepProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading || provider.dateLoading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF48D6FF)));
              }
              
              final session = provider.selectedSession;
              if (session == null) {
                return const Center(child: Text('Không tìm thấy dữ liệu chi tiết.', style: TextStyle(color: Colors.white)));
              }

              return SingleChildScrollView(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Thời gian phân bổ'),
                  const SizedBox(height: AppSpacing.gapLg),
                  SleepTimelineBar(session: session),
                  const SizedBox(height: 32),
                  
                  _SectionHeader(title: 'Cơ cấu giấc ngủ'),
                  const SizedBox(height: AppSpacing.gapLg),
                  PhaseCompositionChart(session: session),
                  const SizedBox(height: 32),
                  
                  _SectionHeader(title: 'Chi tiết chỉ số'),
                  const SizedBox(height: AppSpacing.gapLg),
                  _buildMetrics(session),
                ],
              ),
            );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetrics(SleepSession session) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E38),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: const Color(0x264B5E82)),
      ),
      child: Column(
        children: [
          MetricTile(icon: Icons.hotel_rounded, iconColor: const Color(0xFF48A9D6), label: 'Thời gian trên giường', value: session.inBedText),
          const Divider(color: Color(0x224B5E82), height: 1),
          MetricTile(icon: Icons.nightlight_rounded, iconColor: const Color(0xFF9C6ADE), label: 'Thời gian thức', value: session.awakeText),
          const Divider(color: Color(0x224B5E82), height: 1),
          MetricTile(icon: Icons.alarm_rounded, iconColor: const Color(0xFFFFC400), label: 'Số lần thức giấc', value: '${session.wakeCount}', unit: 'lần'),
          const Divider(color: Color(0x224B5E82), height: 1),
          MetricTile(icon: Icons.percent_rounded, iconColor: const Color(0xFF4CAF50), label: 'Hiệu quả giấc ngủ', value: '${(session.efficiencyRatio * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: AppSpacing.gapLg, decoration: BoxDecoration(color: const Color(0xFF48D6FF), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: AppSpacing.gapSm),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
