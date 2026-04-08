import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/emergency/emergency_sticky_bar.dart';
import '../../../../shared/presentation/shell/app_shell_bottom_nav.dart';
import '../../../../shared/presentation/shell/main_scaffold_shell.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../providers/home_dashboard_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../device/models/device_model.dart';
import '../../../device/providers/device_provider.dart';
import '../../../sleep_analysis/providers/sleep_provider.dart';
import '../models/home_dashboard_view_model.dart';
import '../widgets/connection_status_strip.dart' show DeviceConnectionUiState;
import '../widgets/dashboard_greeting_header.dart';
import '../widgets/dashboard_secondary_links.dart';
import '../widgets/dashboard_top_banner_area.dart';
import '../widgets/health_status_hero_card.dart';
import '../widgets/live_vitals_section.dart';
import '../widgets/risk_insight_card.dart';
import '../widgets/sleep_insight_card.dart';
import '../widgets/vital_metric_card.dart';

bool hasRecentDeviceConnection(
  DeviceModel device, {
  DateTime? now,
  Duration syncGrace = const Duration(minutes: 5),
}) {
  if (!device.isActive) {
    return false;
  }
  if (device.isOnline) {
    return true;
  }
  final referenceTime = now ?? DateTime.now();
  final lastSyncAt = device.lastSyncAt;
  if (lastSyncAt == null) {
    return false;
  }
  return !referenceTime.difference(lastSyncAt).isNegative &&
      referenceTime.difference(lastSyncAt) <= syncGrace;
}

DeviceConnectionUiState resolveDashboardConnectionState({
  required List<DeviceModel> activeDevices,
  required bool isStale,
  DateTime? now,
}) {
  if (activeDevices.isEmpty) {
    return DeviceConnectionUiState.notPaired;
  }

  final referenceTime = now ?? DateTime.now();
  final hasConnectedDevice = activeDevices.any(
    (device) => hasRecentDeviceConnection(device, now: referenceTime),
  );
  if (hasConnectedDevice || !isStale) {
    return DeviceConnectionUiState.connected;
  }
  return DeviceConnectionUiState.offline;
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 1);
  static const Duration _notificationRefreshInterval = Duration(seconds: 5);

  final ApiClient _apiClient = ApiClient();
  late final HomeDashboardProvider _dashboardProvider;
  late final SleepProvider _sleepProvider;
  late final DeviceProvider _deviceProvider;
  Timer? _autoRefreshTimer;
  Timer? _notificationRefreshTimer;
  bool _isRefreshing = false;
  bool _isFetchingUnreadCount = false;
  int _unreadNotificationCount = 0;

  Future<void> _refreshDashboard({bool silent = false}) async {
    if (!mounted || _isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      await _dashboardProvider.loadDashboardData(silent: silent);
    } finally {
      _isRefreshing = false;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      _refreshDashboard(silent: true);
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _fetchUnreadNotificationCount() async {
    if (!mounted || _isFetchingUnreadCount) {
      return;
    }

    _isFetchingUnreadCount = true;
    try {
      final result = await _apiClient.get(
        '/notifications',
        queryParams: {'limit': 1, 'offset': 0},
      );

      final unreadCount = (result['unread_count'] as num?)?.toInt() ?? 0;
      if (!mounted) {
        return;
      }

      if (unreadCount != _unreadNotificationCount) {
        setState(() {
          _unreadNotificationCount = unreadCount;
        });
      }
    } catch (_) {
      // Ignore transient errors and keep the previous unread count.
    } finally {
      _isFetchingUnreadCount = false;
    }
  }

  void _startNotificationRefresh() {
    _notificationRefreshTimer?.cancel();
    _notificationRefreshTimer = Timer.periodic(_notificationRefreshInterval, (
      _,
    ) {
      _fetchUnreadNotificationCount();
    });
  }

  void _stopNotificationRefresh() {
    _notificationRefreshTimer?.cancel();
    _notificationRefreshTimer = null;
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, AppRouter.notifications);
    await _fetchUnreadNotificationCount();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _dashboardProvider = context.read<HomeDashboardProvider>();
    _sleepProvider = context.read<SleepProvider>();
    _deviceProvider = context.read<DeviceProvider>();

    // Gọi sau khi build xong (an toàn context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
      _startAutoRefresh();
      _fetchUnreadNotificationCount();
      _startNotificationRefresh();

      if (_sleepProvider.loadState == SleepLoadState.initial) {
        _sleepProvider.loadAll();
      }

      if (_deviceProvider.devices.isEmpty && !_deviceProvider.isLoading) {
        _deviceProvider.fetchDevices();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
      _refreshDashboard(silent: true);
      _fetchUnreadNotificationCount();
      _startNotificationRefresh();
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAutoRefresh();
      _stopNotificationRefresh();
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _stopNotificationRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
          child: SafeArea(
            bottom: false,
            child: _DashboardBody(
              vm: vm,
              provider: provider,
              unreadNotificationCount: _unreadNotificationCount,
              onOpenNotifications: _openNotifications,
            ),
          ),
        );
      },
    );
  }

  HomeDashboardViewModel _buildViewModel(
    BuildContext context,
    HomeDashboardProvider provider,
  ) {
    // Get current user from AuthProvider
    final authProvider = context.read<AuthProvider>();
    final displayName = authProvider.currentUser?.fullName ?? 'Người dùng';

    // Format vital values
    final heartRateStr = provider.heartRate != null
        ? '${provider.heartRate!.toStringAsFixed(0)} BPM'
        : '--';
    final spo2Str = provider.spo2 != null
        ? '${provider.spo2!.toStringAsFixed(0)}%'
        : '--';
    final bpStr =
        provider.bloodPressureSys != null && provider.bloodPressureDia != null
        ? '${provider.bloodPressureSys!.toStringAsFixed(0)}/${provider.bloodPressureDia!.toStringAsFixed(0)}'
        : '--';
    final tempStr = provider.temperature != null
        ? '${provider.temperature!.toStringAsFixed(1)}°C'
        : '--';

    final hrState = _getHeartRateState(heartRate: provider.heartRate);
    final spo2State = _getSpo2State(spo2: provider.spo2);
    final bpState = _getBloodPressureState(
      systolic: provider.bloodPressureSys,
      diastolic: provider.bloodPressureDia,
    );
    final tempState = _getTemperatureState(temperature: provider.temperature);

    final activeDevices = _deviceProvider.devices
        .where((device) => device.isActive)
        .toList();
    final deviceConnectionState = resolveDashboardConnectionState(
      activeDevices: activeDevices,
      isStale: provider.vitalsStale,
    );
    final primaryDevice = _pickPrimaryDevice(activeDevices);
    final overallStatus = _getOverallStatus(
      level: provider.riskLevel,
      deviceState: deviceConnectionState,
    );

    return HomeDashboardViewModel(
      onRefresh: () async {
        await provider.refreshDashboard();
      },
      displayName: displayName,
      latestUpdatedLabel: provider.vitalsTimestamp != null
          ? 'Cập nhật lúc ${provider.vitalsTimestamp!.hour}:${provider.vitalsTimestamp!.minute.toString().padLeft(2, '0')}'
          : 'Đang tải dữ liệu...',
      overallStatus: overallStatus,
      heroTitle: _heroTitleForStatus(overallStatus),
      heroSummary: provider.riskLevel != null
          ? 'Mức rủi ro: ${provider.riskLevel}'
          : 'Các chỉ số đang được đồng bộ...',
      deviceConnectionState: deviceConnectionState,
      batteryPercent: primaryDevice?.batteryLevel,
      isOffline: deviceConnectionState == DeviceConnectionUiState.offline,
      hasWarningBanner:
          overallStatus == DashboardOverallStatus.warning ||
          overallStatus == DashboardOverallStatus.critical,
      hasError: provider.error != null,
      vitalItems: [
        VitalMetricItem(
          type: VitalMetricType.heartRate,
          label: 'Nhịp tim',
          value: heartRateStr,
          statusLabel: _statusLabelForState(
            hrState,
            isStale: provider.vitalsStale,
            hasValue: provider.heartRate != null,
          ),
          visualState: hrState,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/vital-detail',
              arguments: {'vitalType': 'hr'},
            );
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.spo2,
          label: 'SpO2',
          value: spo2Str,
          statusLabel: _statusLabelForState(
            spo2State,
            isStale: provider.vitalsStale,
            hasValue: provider.spo2 != null,
          ),
          visualState: spo2State,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/vital-detail',
              arguments: {'vitalType': 'spo2'},
            );
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.bloodPressure,
          label: 'Huyết áp',
          value: bpStr,
          statusLabel: _statusLabelForState(
            bpState,
            isStale: provider.vitalsStale,
            hasValue:
                provider.bloodPressureSys != null &&
                provider.bloodPressureDia != null,
          ),
          visualState: bpState,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/vital-detail',
              arguments: {'vitalType': 'bp'},
            );
          },
        ),
        VitalMetricItem(
          type: VitalMetricType.temperature,
          label: 'Nhiệt độ',
          value: tempStr,
          statusLabel: _statusLabelForState(
            tempState,
            isStale: provider.vitalsStale,
            hasValue: provider.temperature != null,
          ),
          visualState: tempState,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/vital-detail',
              arguments: {'vitalType': 'temp'},
            );
          },
        ),
      ],
      sleepDurationLabel: provider.sleepData != null
          ? '${(provider.sleepData!['in_bed_minutes'] as int?) ?? 0 ~/ 60}h'
          : '-- h',
      sleepDurationMinutes:
          (provider.sleepData?['in_bed_minutes'] as int?) ?? 0,
      sleepInsightSummary: provider.sleepData != null
          ? 'Quality: ${provider.sleepData!['quality_score']}%'
          : 'Chưa có dữ liệu giấc ngủ',
      riskScoreLabel: provider.latestRiskScore?.toStringAsFixed(0) ?? '--',
      riskLevelLabel: provider.riskLevel ?? 'Không xác định',
      riskSummary: provider.riskLevel == 'low'
          ? 'Sức khoẻ của bạn đang ở mức ổn định'
          : provider.riskLevel == 'medium' || provider.riskLevel == 'moderate'
          ? 'Một số chỉ số cần chú ý trong hôm nay'
          : provider.riskLevel == 'high'
          ? 'Cần theo dõi các chỉ số sức khỏe'
          : 'Cập nhật dữ liệu...',
      riskVisualState: _getRiskVisualState(provider.riskLevel),
    );
  }

  DeviceModel? _pickPrimaryDevice(List<DeviceModel> activeDevices) {
    for (final device in activeDevices) {
      if (hasRecentDeviceConnection(device)) {
        return device;
      }
    }
    return activeDevices.isNotEmpty ? activeDevices.first : null;
  }

  DashboardOverallStatus _getOverallStatus({
    required String? level,
    required DeviceConnectionUiState deviceState,
  }) {
    if (deviceState == DeviceConnectionUiState.notPaired) {
      return DashboardOverallStatus.noDevice;
    }
    if (deviceState == DeviceConnectionUiState.offline) {
      return DashboardOverallStatus.offline;
    }

    final normalized = level?.trim().toLowerCase();
    return switch (normalized) {
      'high' || 'critical' => DashboardOverallStatus.critical,
      'medium' || 'moderate' => DashboardOverallStatus.warning,
      _ => DashboardOverallStatus.normal,
    };
  }

  String _heroTitleForStatus(DashboardOverallStatus status) {
    return switch (status) {
      DashboardOverallStatus.normal => 'Ổn định hôm nay',
      DashboardOverallStatus.warning => 'Cần chú ý',
      DashboardOverallStatus.critical => 'Nguy cơ cao',
      DashboardOverallStatus.noDevice => 'Chưa kết nối thiết bị',
      DashboardOverallStatus.offline => 'Thiết bị ngoại tuyến',
    };
  }

  VitalMetricVisualState _getHeartRateState({required double? heartRate}) {
    if (heartRate == null) return VitalMetricVisualState.empty;
    if (heartRate < 50 || heartRate > 120) {
      return VitalMetricVisualState.critical;
    }
    if (heartRate < 60 || heartRate > 100) {
      return VitalMetricVisualState.warning;
    }
    return VitalMetricVisualState.normal;
  }

  VitalMetricVisualState _getSpo2State({required double? spo2}) {
    if (spo2 == null) return VitalMetricVisualState.empty;
    if (spo2 < 90) {
      return VitalMetricVisualState.critical;
    }
    if (spo2 < 95) {
      return VitalMetricVisualState.warning;
    }
    return VitalMetricVisualState.normal;
  }

  VitalMetricVisualState _getBloodPressureState({
    required double? systolic,
    required double? diastolic,
  }) {
    if (systolic == null || diastolic == null) {
      return VitalMetricVisualState.empty;
    }
    if (systolic >= 180 ||
        diastolic >= 120 ||
        systolic < 80 ||
        diastolic < 50) {
      return VitalMetricVisualState.critical;
    }
    if (systolic >= 140 || diastolic >= 90 || systolic < 90 || diastolic < 60) {
      return VitalMetricVisualState.warning;
    }
    return VitalMetricVisualState.normal;
  }

  VitalMetricVisualState _getTemperatureState({required double? temperature}) {
    if (temperature == null) return VitalMetricVisualState.empty;
    if (temperature >= 39 || temperature < 35) {
      return VitalMetricVisualState.critical;
    }
    if (temperature >= 37.5 || temperature < 36) {
      return VitalMetricVisualState.warning;
    }
    return VitalMetricVisualState.normal;
  }

  String _statusLabelForState(
    VitalMetricVisualState state, {
    required bool isStale,
    required bool hasValue,
  }) {
    final baseLabel = switch (state) {
      VitalMetricVisualState.normal => 'Bình thường',
      VitalMetricVisualState.warning => 'Cảnh báo',
      VitalMetricVisualState.critical => 'Nguy cấp',
      VitalMetricVisualState.stale => 'Dữ liệu cũ',
      VitalMetricVisualState.empty => 'Đang tải',
    };

    if (isStale && hasValue && state != VitalMetricVisualState.empty) {
      return '$baseLabel (cũ)';
    }

    return baseLabel;
  }

  RiskVisualState _getRiskVisualState(String? level) {
    return switch (level?.toLowerCase()) {
      'low' => RiskVisualState.low,
      'medium' || 'moderate' => RiskVisualState.moderate,
      'high' => RiskVisualState.high,
      'critical' => RiskVisualState.high,
      _ => RiskVisualState.moderate,
    };
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.vm,
    required this.provider,
    required this.unreadNotificationCount,
    required this.onOpenNotifications,
  });

  final HomeDashboardViewModel vm;
  final HomeDashboardProvider provider;
  final int unreadNotificationCount;
  final Future<void> Function() onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.heartRate == null) {
      return const Center(child: CircularProgressIndicator());
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
                  hasUnreadNotifications: unreadNotificationCount > 0,
                  unreadNotificationCount: unreadNotificationCount,
                  onTapNotifications: () => onOpenNotifications(),
                ),
                const SizedBox(height: AppSpacing.sectionGapMd),
                HealthStatusHeroCard(
                  overallStatus: vm.overallStatus,
                  title: vm.heroTitle,
                  summary: vm.heroSummary,
                ),
                const SizedBox(height: AppSpacing.gapMd),
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
                  onTapNotifications: () {
                    onOpenNotifications();
                  },
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
