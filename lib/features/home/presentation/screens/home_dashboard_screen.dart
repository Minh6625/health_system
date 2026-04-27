import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../../../health_monitoring/models/vital_signs.dart';
import '../models/home_dashboard_view_model.dart';
import '../widgets/connection_status_strip.dart'
    show ConnectionStatusStrip, DeviceConnectionUiState;
import '../widgets/dashboard_greeting_header.dart';
import '../widgets/dashboard_secondary_links.dart';
import '../widgets/dashboard_top_banner_area.dart';
import '../widgets/health_status_hero_card.dart';
import '../widgets/live_vitals_section.dart';
import '../widgets/risk_insight_card.dart';
import '../widgets/sleep_insight_card.dart';
import '../widgets/vital_metric_card.dart';

String? normalizeRiskLevelLabel(String? level) {
  switch (level?.trim().toLowerCase()) {
    case 'low':
      return 'low';
    case 'medium':
    case 'moderate':
    case 'high':
      return 'medium';
    case 'critical':
      return 'critical';
    default:
      return null;
  }
}

String dashboardRiskDisplayLabel(String? level) {
  switch (normalizeRiskLevelLabel(level)) {
    case 'low':
      return 'Ổn định';
    case 'medium':
      return 'Cảnh báo';
    case 'critical':
      return 'Nguy hiểm';
    default:
      return 'Không xác định';
  }
}

String dashboardRiskSummary(String? level) {
  switch (normalizeRiskLevelLabel(level)) {
    case 'low':
      return 'Các chỉ số đang ổn định. Tiếp tục duy trì thói quen hiện tại nhé.';
    case 'medium':
      return 'Một vài chỉ số đang lệch ngưỡng. Hãy nghỉ ngơi và đo lại sau ít giờ.';
    case 'critical':
      return 'Có chỉ số vượt ngưỡng nguy hiểm. Hãy nghỉ ngơi ngay và liên hệ bác sĩ nếu thấy bất thường.';
    default:
      return 'Đang chờ dữ liệu mới từ thiết bị của bạn.';
  }
}

String dashboardHealthSummary({
  required String? backendSummary,
  required bool isStale,
  required String? riskLevel,
}) {
  if (isStale) {
    return 'Dữ liệu đã cũ. Hãy đồng bộ thiết bị để xem đánh giá mới nhất.';
  }
  if (backendSummary != null && backendSummary.trim().isNotEmpty) {
    return backendSummary;
  }
  return dashboardRiskSummary(riskLevel);
}

String sleepQualityLabelVi({required int qualityScore, String? qualityLabel}) {
  final normalizedLabel = qualityLabel?.trim().toUpperCase();
  switch (normalizedLabel) {
    case 'GOOD':
      return 'Tốt';
    case 'AVERAGE':
      return 'Trung bình';
    case 'POOR':
      return 'Kém';
  }

  if (qualityScore >= 80) {
    return 'Tốt';
  }
  if (qualityScore >= 60) {
    return 'Trung bình';
  }
  return 'Kém';
}

RiskVisualState dashboardRiskVisualState(String? level) {
  return switch (normalizeRiskLevelLabel(level)) {
    'low' => RiskVisualState.low,
    'medium' => RiskVisualState.moderate,
    'critical' => RiskVisualState.high,
    _ => RiskVisualState.moderate,
  };
}

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

DateTime? canonicalSleepDateFromPayload(Map<String, dynamic>? sleepData) {
  final rawDate = sleepData?['sleep_date'];
  if (rawDate is DateTime) {
    return DateTime(rawDate.year, rawDate.month, rawDate.day);
  }
  if (rawDate is String) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  return null;
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.profileId,
    this.unreadNotificationCountLoader,
    this.enableAutoRefresh = true,
  });

  final String? profileId;
  final Future<int> Function()? unreadNotificationCountLoader;
  final bool enableAutoRefresh;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 30);
  static const Duration _notificationRefreshInterval = Duration(seconds: 30);
  static const Duration _utcPlus7Offset = Duration(hours: 7);

  final ApiClient _apiClient = ApiClient();
  late final HomeDashboardProvider _dashboardProvider;
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
      final unreadCount = widget.unreadNotificationCountLoader != null
          ? await widget.unreadNotificationCountLoader!()
          : await (() async {
              final result = await _apiClient.get(
                '/notifications',
                queryParams: {'limit': 1, 'offset': 0},
              );
              return (result['unread_count'] as num?)?.toInt() ?? 0;
            })();
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
    _deviceProvider = context.read<DeviceProvider>();
    _dashboardProvider.configureProfile(widget.profileId);

    // Gọi sau khi build xong (an toàn context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDashboard();
      _fetchUnreadNotificationCount();
      if (widget.enableAutoRefresh) {
        _startAutoRefresh();
        _startNotificationRefresh();
      }

      if (_deviceProvider.devices.isEmpty && !_deviceProvider.isLoading) {
        _deviceProvider.fetchDevices();
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _dashboardProvider.configureProfile(widget.profileId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshDashboard();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enableAutoRefresh) {
      return;
    }

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

  DateTime _toUtcPlus7(DateTime value) {
    final utcValue = value.isUtc ? value : value.toUtc();
    return utcValue.add(_utcPlus7Offset);
  }

  String _buildLatestUpdatedLabel(HomeDashboardProvider provider) {
    final latestTimestamp = provider.latestDashboardTimestamp;
    if (latestTimestamp == null) {
      return 'Đang tải dữ liệu...';
    }

    final utcPlus7Time = _toUtcPlus7(latestTimestamp);
    return 'Cập nhật lúc ${DateFormat('HH:mm:ss').format(utcPlus7Time)}';
  }

  HomeDashboardViewModel _buildViewModel(
    BuildContext context,
    HomeDashboardProvider provider,
  ) {
    final authProvider = context.read<AuthProvider>();
    final isLinkedProfile =
        widget.profileId != null && widget.profileId != 'self';
    final displayName = isLinkedProfile
        ? 'Hồ sơ người thân'
        : authProvider.currentUser?.fullName ?? 'Người dùng';

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

    final hrState = _visualStateFromVitalStatus(
      classifyHeartRateStatus(provider.heartRate),
    );
    final spo2State = _visualStateFromVitalStatus(
      classifySpo2Status(provider.spo2),
    );
    final bpState = _visualStateFromVitalStatus(
      classifyBloodPressureStatus(
        systolic: provider.bloodPressureSys,
        diastolic: provider.bloodPressureDia,
      ),
    );
    final tempState = _visualStateFromVitalStatus(
      classifyTemperatureStatus(provider.temperature),
    );

    final activeDevices = _deviceProvider.devices
        .where((device) => device.isActive)
        .toList();
    final deviceConnectionState = resolveDashboardConnectionState(
      activeDevices: activeDevices,
      isStale: provider.vitalsStale,
    );
    final primaryDevice = _pickPrimaryDevice(activeDevices);
    final normalizedRiskLevel = normalizeRiskLevelLabel(provider.riskLevel);
    final displayRiskLevel = dashboardRiskDisplayLabel(provider.riskLevel);
    final overallStatus = _getOverallStatus(
      level: provider.riskLevel,
      deviceState: deviceConnectionState,
    );
    final sleepData = provider.sleepData;
    final sleepQualityScore = (sleepData?['quality_score'] as num?)?.toInt();
    final sleepInsightSummary = sleepQualityScore != null
        ? 'Chất lượng: $sleepQualityScore% (${sleepQualityLabelVi(qualityScore: sleepQualityScore, qualityLabel: sleepData?['quality_label'] as String?)})'
        : 'Chưa có dữ liệu giấc ngủ';

    return HomeDashboardViewModel(
      onRefresh: () async {
        await provider.refreshDashboard();
      },
      displayName: displayName,
      latestUpdatedLabel: _buildLatestUpdatedLabel(provider),
      overallStatus: overallStatus,
      heroTitle: _heroTitleForStatus(overallStatus),
      heroSummary: normalizedRiskLevel != null
          ? (provider.reportStale
                ? 'Dữ liệu đánh giá sức khỏe đã cũ.'
                : 'Trạng thái sức khỏe hiện tại: $displayRiskLevel')
          : 'Các chỉ số đang được đồng bộ...',
      deviceConnectionState: deviceConnectionState,
      batteryPercent: primaryDevice?.batteryLevel,
      isOffline: deviceConnectionState == DeviceConnectionUiState.offline,
      hasWarningBanner:
          overallStatus == DashboardOverallStatus.warning ||
          overallStatus == DashboardOverallStatus.critical,
      hasError: provider.error != null || provider.hasSectionErrors,
      errorMessage: provider.error ?? provider.sectionErrorMessage,
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
              arguments: {'vitalType': 'hr', 'profileId': widget.profileId},
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
              arguments: {'vitalType': 'spo2', 'profileId': widget.profileId},
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
              arguments: {'vitalType': 'bp', 'profileId': widget.profileId},
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
              arguments: {'vitalType': 'temp', 'profileId': widget.profileId},
            );
          },
        ),
      ],
      sleepDurationLabel: provider.sleepData != null
          ? '${((provider.sleepData!['in_bed_minutes'] as int?) ?? 0) ~/ 60}h'
          : '-- h',
      sleepDurationMinutes:
          (provider.sleepData?['in_bed_minutes'] as int?) ?? 0,
      sleepInsightSummary: sleepInsightSummary,
      riskScoreLabel: provider.healthScore?.toStringAsFixed(0) ?? '--',
      riskLevelLabel:
          provider.healthLevel ??
          (normalizedRiskLevel != null ? displayRiskLevel : 'Không xác định'),
      riskSummary: dashboardHealthSummary(
        backendSummary: provider.healthSummary,
        isStale: provider.reportStale,
        riskLevel: provider.riskLevel,
      ),
      riskVisualState: dashboardRiskVisualState(provider.riskLevel),
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

    final normalized = normalizeRiskLevelLabel(level);
    return switch (normalized) {
      'critical' => DashboardOverallStatus.critical,
      'medium' => DashboardOverallStatus.warning,
      _ => DashboardOverallStatus.normal,
    };
  }

  String _heroTitleForStatus(DashboardOverallStatus status) {
    return switch (status) {
      DashboardOverallStatus.normal => 'Hôm nay sức khỏe của bạn khá ổn định',
      DashboardOverallStatus.warning => 'Hôm nay có chỉ số sức khỏe cần chú ý',
      DashboardOverallStatus.critical =>
        'Hôm nay sức khỏe của bạn đang ở mức nguy hiểm',
      DashboardOverallStatus.noDevice => 'Chưa kết nối thiết bị',
      DashboardOverallStatus.offline => 'Thiết bị ngoại tuyến',
    };
  }

  VitalMetricVisualState _visualStateFromVitalStatus(VitalStatus status) {
    switch (status) {
      case VitalStatus.normal:
        return VitalMetricVisualState.normal;
      case VitalStatus.warning:
        return VitalMetricVisualState.warning;
      case VitalStatus.critical:
        return VitalMetricVisualState.critical;
      case VitalStatus.unknown:
        return VitalMetricVisualState.empty;
    }
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
                // ── Vùng A · Trạng thái tổng quan ─────────────────────
                DashboardGreetingHeader(
                  displayName: vm.displayName,
                  avatarUrl: vm.avatarUrl,
                  latestUpdatedLabel: vm.latestUpdatedLabel,
                  hasUnreadNotifications: unreadNotificationCount > 0,
                  unreadNotificationCount: unreadNotificationCount,
                  onTapNotifications: () => onOpenNotifications(),
                ),
                const SizedBox(height: AppSpacing.gapMd),
                HealthStatusHeroCard(
                  overallStatus: vm.overallStatus,
                  title: vm.heroTitle,
                  summary: vm.heroSummary,
                ),
                const SizedBox(height: AppSpacing.gapSm),
                ConnectionStatusStrip(
                  deviceConnectionState: vm.deviceConnectionState,
                  batteryPercent: vm.batteryPercent,
                  lastUpdatedLabel: vm.latestUpdatedLabel,
                  onTapDevice: () {
                    Navigator.pushReplacementNamed(context, '/device');
                  },
                ),
                DashboardTopBannerArea(vm: vm),

                // ── Vùng B · Chỉ số hôm nay ───────────────────────────
                const SizedBox(height: AppSpacing.sectionGapXl),
                LiveVitalsSection(
                  items: vm.vitalItems,
                  onTapHistory: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.healthReport,
                      arguments: {'profileId': provider.profileId},
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.gapMd),
                RiskInsightCard(
                  scoreLabel: vm.riskScoreLabel,
                  levelLabel: vm.riskLevelLabel,
                  summary: vm.riskSummary,
                  riskVisualState: vm.riskVisualState,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.riskReport,
                      arguments: {'profileId': provider.profileId},
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.gapMd),
                SleepInsightCard(
                  sleepDurationMinutes: vm.sleepDurationMinutes,
                  durationLabel: vm.sleepDurationLabel,
                  insightSummary: vm.sleepInsightSummary,
                  onTap: () {
                    final sleepDate = canonicalSleepDateFromPayload(
                      provider.sleepData,
                    );
                    final arguments = <String, dynamic>{
                      'profileId': provider.profileId,
                    };
                    if (sleepDate != null) {
                      arguments['date'] = sleepDate;
                    }
                    Navigator.pushNamed(
                      context,
                      AppRouter.sleepReport,
                      arguments: arguments,
                    );
                  },
                ),

                // ── Vùng C · Thao tác nhanh ───────────────────────────
                // Title 'Thao tác nhanh' is rendered by DashboardSecondaryLinks itself.
                const SizedBox(height: AppSpacing.sectionGapXl),
                DashboardSecondaryLinks(
                  onTapHistory: () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.healthReport,
                      arguments: {'profileId': provider.profileId},
                    );
                  },
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
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.gapSm)),
        ],
      ),
    );
  }
}

