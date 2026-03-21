import 'package:flutter/material.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/shell/app_shell_bottom_nav.dart';
import '../../../../shared/presentation/shell/main_scaffold_shell.dart';
import '../../../../shared/presentation/emergency/emergency_sticky_bar.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../models/home_dashboard_view_model.dart';
import '../widgets/dashboard_greeting_header.dart';
import '../widgets/dashboard_secondary_links.dart';
import '../widgets/connection_status_strip.dart' show DeviceConnectionUiState;
import '../widgets/dashboard_top_banner_area.dart';
import '../widgets/health_status_hero_card.dart';
import '../widgets/live_vitals_section.dart';
import '../widgets/risk_insight_card.dart';
import '../widgets/sleep_insight_card.dart';
import '../widgets/vital_metric_card.dart';

class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In a real implementation, this ViewModel would come from a State Management solution
    // like Bloc (e.g. context.watch<HomeDashboardCubit>().state.toViewModel())
    // For now, we use a mocked view model to demonstrate the layout.
    final vm = _getMockViewModel(context);

    return MainScaffoldShell(
      bottomNavigation: AppShellBottomNav(
        currentTab: AppMainTab.me,
        familyHasAlertBadge: vm.familyHasAlertBadge,
        deviceHasAttentionBadge: vm.deviceNeedsAttention,
        onTabSelected: (tab) {
          switch (tab) {
            case AppMainTab.device:
              Navigator.pushReplacementNamed(context, '/device');
              break;
            case AppMainTab.family:
              Navigator.pushReplacementNamed(context, '/family-management');
              break;
            case AppMainTab.profile:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
            case AppMainTab.me:
              // Already on dashboard
              break;
          }
        },
      ),
      stickyBottomBar: EmergencyStickyBar(
        emphasis: vm.emergencyBarEmphasis,
        onPressed: () {
          Navigator.pushNamed(context, AppRouter.manualSos);
        },
      ),
      child: SafeArea(bottom: false, child: _DashboardBody(vm: vm)),
    );
  }

  HomeDashboardViewModel _getMockViewModel(BuildContext context) {
    return HomeDashboardViewModel(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      displayName: 'Minh Thiện',
      latestUpdatedLabel: 'Cập nhật sức khoẻ mới nhất lúc 08:42',
      overallStatus: DashboardOverallStatus.normal,
      heroTitle: 'Ổn định hôm nay',
      heroSummary: 'Các chỉ số đang ở mức an toàn',
      deviceConnectionState: DeviceConnectionUiState.connected,
      batteryPercent: 82,
      vitalItems: [
        VitalMetricItem(
          type: VitalMetricType.heartRate,
          label: 'Nhịp tim',
          value: '82 BPM',
          statusLabel: 'Bình thường',
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'hr'});
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.spo2,
          label: 'SpO2',
          value: '97%',
          statusLabel: 'Tốt',
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'spo2'});
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.bloodPressure,
          label: 'Huyết áp',
          value: '120/80',
          statusLabel: 'Theo dõi',
          visualState: VitalMetricVisualState.warning,
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'bp'});
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.temperature,
          label: 'Nhiệt độ',
          value: '36.5°C',
          statusLabel: 'Tốt',
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'temp'});
          },
        ),
      ],
      sleepDurationLabel: '7h20',
      sleepDurationMinutes: 440,
      sleepInsightSummary: 'Đêm qua bạn ngủ sâu và ổn định',
      riskScoreLabel: '78',
      riskLevelLabel: 'Thấp',
      riskSummary: 'Sức khoẻ của bạn đang ở mức ổn định',
      riskVisualState: RiskVisualState.low,
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.vm});

  final HomeDashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: vm.onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: AppSpacing.screenHorizontalPadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                DashboardGreetingHeader(
                  displayName: vm.displayName,
                  avatarUrl: vm.avatarUrl,
                  latestUpdatedLabel: vm.latestUpdatedLabel,
                  onTapNotifications: () {},
                ),
                const SizedBox(height: AppSpacing.sectionGapMd),
                RiskInsightCard(
                  scoreLabel: vm.riskScoreLabel,
                  levelLabel: vm.riskLevelLabel,
                  summary: vm.riskSummary,
                  riskVisualState: vm.riskVisualState,
                  onTap: () {
                    Navigator.pushNamed(context, AppRouter.riskReport);
                  },
                ),
                DashboardTopBannerArea(vm: vm),
                const SizedBox(height: AppSpacing.gapMd),
                LiveVitalsSection(items: vm.vitalItems, onTapHistory: () {}),
                const SizedBox(height: AppSpacing.sectionGapMd),
                SleepInsightCard(
                  sleepDurationMinutes: vm.sleepDurationMinutes,
                  durationLabel: vm.sleepDurationLabel,
                  insightSummary: vm.sleepInsightSummary,
                  onTap: () {
                    Navigator.pushNamed(context, '/sleep-report');
                  },
                ),
                const SizedBox(height: AppSpacing.sectionGapMd),
                DashboardSecondaryLinks(
                  onTapHistory: () {},
                  onTapDeviceSettings: () {
                    Navigator.pushReplacementNamed(context, '/device');
                  },
                  onTapNotifications: () {},
                ),
                const SizedBox(height: AppSpacing.sectionGapXl),
              ]),
            ),
          ),
          // Thêm một khoảng đệm ở dưới cùng để nội dung không bị che bởi EmergencyStickyBar
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
