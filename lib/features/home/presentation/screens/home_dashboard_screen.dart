import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/shell/app_shell_bottom_nav.dart';
import '../../../../shared/presentation/shell/main_scaffold_shell.dart';
import '../../../../shared/presentation/emergency/emergency_sticky_bar.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../providers/home_dashboard_provider.dart';
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
import '../../../auth/providers/auth_provider.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load dashboard data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeDashboardProvider>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeDashboardProvider>(
      builder: (context, provider, child) {
        final vm = _buildViewModel(context, provider);

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
          child: SafeArea(bottom: false, child: _DashboardBody(vm: vm, provider: provider)),
        );
      },
    );
  }

  HomeDashboardViewModel _buildViewModel(BuildContext context, HomeDashboardProvider provider) {
    // Get current user from AuthProvider
    final authProvider = context.read<AuthProvider>();
    final displayName = authProvider.currentUser?.fullName ?? 'Người dùng';

    // Format vital values
    final heartRateStr = provider.heartRate != null ? '${provider.heartRate!.toStringAsFixed(0)} BPM' : '--';
    final spo2Str = provider.spo2 != null ? '${provider.spo2!.toStringAsFixed(0)}%' : '--';
    final bpStr = provider.bloodPressureSys != null && provider.bloodPressureDia != null
        ? '${provider.bloodPressureSys!.toStringAsFixed(0)}/${provider.bloodPressureDia!.toStringAsFixed(0)}'
        : '--';
    final tempStr = provider.temperature != null ? '${provider.temperature!.toStringAsFixed(1)}°C' : '--';

    // Determine BP status
    VitalMetricVisualState bpState = VitalMetricVisualState.normal;
    if (provider.bloodPressureSys != null && provider.bloodPressureSys! > 140) {
      bpState = VitalMetricVisualState.warning;
    }

    return HomeDashboardViewModel(
      onRefresh: () async {
        await provider.refreshDashboard();
      },
      displayName: displayName,
      latestUpdatedLabel: provider.vitalsTimestamp != null
          ? 'Cập nhật lúc ${provider.vitalsTimestamp!.hour}:${provider.vitalsTimestamp!.minute.toString().padLeft(2, '0')}'
          : 'Đang tải dữ liệu...',
      overallStatus: DashboardOverallStatus.normal,
      heroTitle: provider.riskLevel == 'low' ? 'Ổn định hôm nay' : 'Cần theo dõi',
      heroSummary: provider.riskLevel != null
          ? 'Mức rủi ro: ${provider.riskLevel}'
          : 'Các chỉ số đang được đồng bộ...',
      deviceConnectionState: DeviceConnectionUiState.connected,
      batteryPercent: 82,
      vitalItems: [
        VitalMetricItem(
          type: VitalMetricType.heartRate,
          label: 'Nhịp tim',
          value: heartRateStr,
          statusLabel: provider.heartRate == null ? 'Đang tải' : (provider.heartRate! < 60 || provider.heartRate! > 100  ? 'Cảnh báo' : 'Bình thường'),
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'hr'});
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.spo2,
          label: 'SpO2',
          value: spo2Str,
          statusLabel: provider.spo2 == null ? 'Đang tải' : (provider.spo2! < 95 ? 'Cảnh báo' : 'Tốt'),
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'spo2'});
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.bloodPressure,
          label: 'Huyết áp',
          value: bpStr,
          statusLabel: provider.bloodPressureSys == null ? 'Đang tải' : 'Theo dõi',
          visualState: bpState,
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'bp'});
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.temperature,
          label: 'Nhiệt độ',
          value: tempStr,
          statusLabel: provider.temperature == null ? 'Đang tải' : 'Tốt',
          onTap: () {
            Navigator.pushNamed(context, '/vital-detail', arguments: {'vitalType': 'temp'});
          },
        ),
      ],
      sleepDurationLabel: provider.sleepData != null
          ? '${(provider.sleepData!['in_bed_minutes'] as int?) ?? 0 ~/ 60}h'
          : '-- h',
      sleepDurationMinutes: (provider.sleepData?['in_bed_minutes'] as int?) ?? 0,
      sleepInsightSummary: provider.sleepData != null
          ? 'Quality: ${provider.sleepData!['quality_score']}%'
          : 'Chưa có dữ liệu giấc ngủ',
      riskScoreLabel: provider.latestRiskScore?.toStringAsFixed(0) ?? '--',
      riskLevelLabel: provider.riskLevel ?? 'Không xác định',
      riskSummary: provider.riskLevel == 'low'
          ? 'Sức khoẻ của bạn đang ở mức ổn định'
          : provider.riskLevel == 'high'
              ? 'Cần theo dõi các chỉ số sức khỏe'
              : 'Cập nhật dữ liệu...',
      riskVisualState: _getRiskVisualState(provider.riskLevel),
    );
  }

  RiskVisualState _getRiskVisualState(String? level) {
    return switch (level?.toLowerCase()) {
      'low' => RiskVisualState.low,
      'medium' => RiskVisualState.moderate,
      'high' => RiskVisualState.high,
      'critical' => RiskVisualState.high,
      _ => RiskVisualState.moderate,
    };
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.vm, required this.provider});

  final HomeDashboardViewModel vm;
  final HomeDashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.heartRate == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (provider.error != null && provider.heartRate == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Lỗi: ${provider.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadDashboardData(),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

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
