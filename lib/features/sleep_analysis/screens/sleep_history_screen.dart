import 'package:flutter/material.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:healthguard/features/sleep_analysis/widgets/sleep_trend_chart.dart';
import 'package:healthguard/features/sleep_analysis/widgets/starry_background.dart';
import 'package:healthguard/shared/presentation/theme/app_radii.dart';
import 'package:healthguard/shared/presentation/theme/app_spacing.dart';
import 'package:provider/provider.dart';

class SleepHistoryScreen extends StatefulWidget {
  final String? profileId;

  const SleepHistoryScreen({super.key, this.profileId});

  @override
  State<SleepHistoryScreen> createState() => _SleepHistoryScreenState();
}

class _SleepHistoryScreenState extends State<SleepHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SleepProvider>().loadAll(patientId: widget.profileId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF071220),
      appBar: AppBar(
        title: const Text('Lịch sử giấc ngủ'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StarryBackground(
        child: SafeArea(
          child: Consumer<SleepProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF48D6FF)));
              }

              final history = provider.historyList;
              if (history.isEmpty) {
                return const Center(child: Text('Chưa có dữ liệu lịch sử.', style: TextStyle(color: Colors.white)));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapLg, vertical: AppSpacing.sectionGapXl),
                    child: SleepTrendChart(
                      historyList: history,
                      highlightedDate: provider.selectedSession?.endTime,
                      onSessionTapped: (session) {
                        provider.selectHistorySession(session);
                        Navigator.pop(context); // Return to report with new date selected
                      },
                    ),
                  ),
                  const Divider(color: Color(0x3348D6FF), height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: AppSpacing.cardPadding,
                      itemCount: history.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.gapMd),
                      itemBuilder: (context, index) {
                        final session = history[history.length - 1 - index]; // Newest first
                        return InkWell(
                          onTap: () {
                            provider.selectHistorySession(session);
                            Navigator.pop(context);
                          },
                          borderRadius: AppRadii.cardRadius,
                          child: Container(
                            padding: AppSpacing.cardPadding,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1E38),
                              borderRadius: AppRadii.cardRadius,
                              border: Border.all(color: const Color(0x332C4367)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${session.startTime.day.toString().padLeft(2, '0')}/${session.startTime.month.toString().padLeft(2, '0')}',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: AppSpacing.gapXs),
                                    Text(
                                      session.qualityLabel,
                                      style: TextStyle(
                                        color: session.qualityScore >= 70 ? Colors.greenAccent : (session.qualityScore >= 50 ? Colors.orangeAccent : Colors.redAccent),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      session.sleepText,
                                      style: const TextStyle(color: Color(0xFF48D6FF), fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: AppSpacing.gapSm),
                                    const Icon(Icons.chevron_right, color: Color(0xFF5B7FA6)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
