import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../shared/presentation/emergency/emergency_sticky_bar.dart';
import '../../../../shared/presentation/shell/app_shell_bottom_nav.dart';
import '../../../../shared/presentation/shell/main_scaffold_shell.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../device/models/device_model.dart';
import '../../../device/providers/device_provider.dart';
import '../../../health_monitoring/models/vital_signs.dart';
import '../../../health_monitoring/providers/vital_signs_provider.dart'
    show VitalsUIState;
import '../../../sleep_analysis/models/sleep_session.dart';
import '../../../sleep_analysis/providers/sleep_provider.dart';
import '../models/home_dashboard_view_model.dart';
import '../providers/home_dashboard_provider.dart';
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

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late final HomeDashboardProvider _dashboardProvider;
  late final SleepProvider _sleepProvider;
  late final DeviceProvider _deviceProvider;
  late final Listenable _dashboardListenable;

  @override
  void initState() {
    super.initState();
    _dashboardProvider = context.read<HomeDashboardProvider>();
    _sleepProvider = context.read<SleepProvider>();
    _deviceProvider = context.read<DeviceProvider>();
    _dashboardListenable = Listenable.merge([
      _dashboardProvider,
      _sleepProvider,
      _deviceProvider,
    ]);

    _dashboardProvider.startPolling();
    if (_sleepProvider.loadState == SleepLoadState.initial) {
      _sleepProvider.loadAll();
    }
    if (_deviceProvider.devices.isEmpty && !_deviceProvider.isLoading) {
      _deviceProvider.fetchDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dashboardListenable,
      builder: (context, _) {
        final vm = _buildDashboardViewModel(context);
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
      },
    );
  }

  HomeDashboardViewModel _buildDashboardViewModel(BuildContext context) {
    try {
      return _buildLiveViewModel(context);
    } catch (_) {
      return _buildMockFallback(context);
    }
  }

  HomeDashboardViewModel _buildLiveViewModel(BuildContext context) {
    final activeDevices = _deviceProvider.devices
        .where((device) => device.isActive)
        .toList();
    final vitals = _dashboardProvider.vitals;
    final isStale = vitals?.isStale ?? true;
    final updatedAt = vitals?.timestamp;
    final connectionState = resolveDashboardConnectionState(
      activeDevices: activeDevices,
      isStale: isStale,
    );
    final batteryPercent = activeDevices.isEmpty
        ? null
        : activeDevices.first.batteryLevel;
    final statuses = [
      _extractVitalStatus(vitals, 'hr'),
      _extractVitalStatus(vitals, 'spo2'),
      _extractVitalStatus(vitals, 'bp'),
      _extractVitalStatus(vitals, 'temp'),
    ];
    final hasCriticalVitals = statuses.any(
      (status) => status == VitalStatus.critical,
    );
    final hasWarningVitals = statuses.any(
      (status) => status == VitalStatus.warning,
    );
    final hasAnyLoading =
        (_dashboardProvider.state == VitalsUIState.loading && vitals == null) ||
        (_sleepProvider.isLoading && _sleepProvider.latestSession == null) ||
        (_deviceProvider.isLoading && _deviceProvider.devices.isEmpty);
    final hasVitalError = _dashboardProvider.state == VitalsUIState.error;
    final hasAnyData =
        updatedAt != null ||
        _sleepProvider.latestSession != null ||
        activeDevices.isNotEmpty;
    final hasError =
        !hasAnyData &&
        (hasVitalError ||
            _sleepProvider.hasError ||
            _deviceProvider.errorMessage != null);
    final isOffline =
        !hasError && connectionState == DeviceConnectionUiState.offline;
    final hasWarningBanner =
        !hasError && !isOffline && (hasCriticalVitals || hasWarningVitals);
    final sleep = _sleepProvider.latestSession;
    final sleepMinutes = sleep?.sleepMinutes ?? 0;
    final sleepDurationLabel = sleep != null ? sleep.sleepText : '--';
    final sleepSummary = _buildSleepSummary(sleep);
    final overallStatus = _buildOverallStatus(
      connectionState: connectionState,
      hasCriticalVitals: hasCriticalVitals,
      hasWarningVitals: hasWarningVitals,
    );

    return HomeDashboardViewModel(
      onRefresh: () async {
        await Future.wait([
          _dashboardProvider.refresh(),
          _sleepProvider.loadAll(forceRefresh: true),
          _deviceProvider.fetchDevices(forceRefresh: true),
        ]);
      },
      displayName: _resolveDisplayName(context),
      latestUpdatedLabel: _buildUpdatedLabel(
        context,
        updatedAt: updatedAt,
        isStale: isStale,
        hasAnyLoading: hasAnyLoading,
        hasActiveDevice: activeDevices.isNotEmpty,
        connectionState: connectionState,
      ),
      overallStatus: overallStatus,
      heroTitle: _buildHeroTitle(overallStatus),
      heroSummary: _buildHeroSummary(overallStatus),
      showCallHelpCta: hasCriticalVitals,
      deviceConnectionState: connectionState,
      batteryPercent: batteryPercent,
      isOffline: isOffline,
      hasWarningBanner: hasWarningBanner,
      hasError: hasError,
      vitalItems: [
        _buildVitalItem(
          context: context,
          type: VitalMetricType.heartRate,
          label: 'Nhịp tim',
          routeVitalType: 'hr',
          vitals: vitals,
          suffix: ' BPM',
          isStale: isStale,
          connectionState: connectionState,
        ),
        _buildVitalItem(
          context: context,
          type: VitalMetricType.spo2,
          label: 'SpO2',
          routeVitalType: 'spo2',
          vitals: vitals,
          suffix: '%',
          isStale: isStale,
          connectionState: connectionState,
        ),
        _buildVitalItem(
          context: context,
          type: VitalMetricType.bloodPressure,
          label: 'Huyết áp',
          routeVitalType: 'bp',
          vitals: vitals,
          isStale: isStale,
          connectionState: connectionState,
        ),
        _buildVitalItem(
          context: context,
          type: VitalMetricType.temperature,
          label: 'Nhiệt độ',
          routeVitalType: 'temp',
          vitals: vitals,
          suffix: '°C',
          isStale: isStale,
          connectionState: connectionState,
        ),
      ],
      sleepDurationLabel: sleepDurationLabel,
      sleepDurationMinutes: sleepMinutes,
      sleepInsightSummary: sleepSummary,
      riskScoreLabel: '--',
      riskLevelLabel: '--',
      riskSummary: 'Chỉ số rủi ro đang được tính toán',
      riskVisualState: RiskVisualState.low,
      familyHasAlertBadge: false,
      deviceNeedsAttention:
          connectionState == DeviceConnectionUiState.offline ||
          _deviceProvider.needsAttentionDevices.isNotEmpty,
      emergencyBarEmphasis: hasCriticalVitals
          ? EmergencyBarEmphasis.heightened
          : EmergencyBarEmphasis.defaultLevel,
    );
  }

  HomeDashboardViewModel _buildMockFallback(BuildContext context) {
    return HomeDashboardViewModel(
      onRefresh: () async {
        await _sleepProvider.loadAll(forceRefresh: true);
        await _deviceProvider.fetchDevices();
      },
      displayName: 'Người dùng',
      latestUpdatedLabel: 'Đang tải dữ liệu sức khoẻ',
      overallStatus: DashboardOverallStatus.offline,
      heroTitle: 'Đang chờ dữ liệu',
      heroSummary: 'Dữ liệu trực tiếp sẽ hiển thị khi thiết bị đồng bộ',
      deviceConnectionState: DeviceConnectionUiState.offline,
      batteryPercent: null,
      isOffline: true,
      vitalItems: [
        VitalMetricItem(
          type: VitalMetricType.heartRate,
          label: 'Nhịp tim',
          value: '--',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
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
          value: '--',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
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
          value: '--/--',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
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
          value: '--',
          statusLabel: 'Chưa có dữ liệu',
          visualState: VitalMetricVisualState.empty,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/vital-detail',
              arguments: {'vitalType': 'temp'},
            );
          },
        ),
      ],
      sleepDurationLabel: '--',
      sleepDurationMinutes: 0,
      sleepInsightSummary: 'Chưa có dữ liệu giấc ngủ',
      riskScoreLabel: '--',
      riskLevelLabel: '--',
      riskSummary: 'Chỉ số rủi ro đang được tính toán',
      riskVisualState: RiskVisualState.low,
      deviceNeedsAttention: true,
    );
  }

  DashboardOverallStatus _buildOverallStatus({
    required DeviceConnectionUiState connectionState,
    required bool hasCriticalVitals,
    required bool hasWarningVitals,
  }) {
    if (connectionState == DeviceConnectionUiState.notPaired) {
      return DashboardOverallStatus.noDevice;
    }
    if (connectionState == DeviceConnectionUiState.offline) {
      return DashboardOverallStatus.offline;
    }
    if (hasCriticalVitals) {
      return DashboardOverallStatus.critical;
    }
    if (hasWarningVitals) {
      return DashboardOverallStatus.warning;
    }
    return DashboardOverallStatus.normal;
  }

  String _buildHeroTitle(DashboardOverallStatus status) {
    switch (status) {
      case DashboardOverallStatus.normal:
        return 'Ổn định hôm nay';
      case DashboardOverallStatus.warning:
        return 'Cần theo dõi';
      case DashboardOverallStatus.critical:
        return 'Cần chú ý ngay';
      case DashboardOverallStatus.noDevice:
        return 'Chưa kết nối đồng hồ';
      case DashboardOverallStatus.offline:
        return 'Đang chờ dữ liệu';
    }
  }

  String _buildHeroSummary(DashboardOverallStatus status) {
    switch (status) {
      case DashboardOverallStatus.normal:
        return 'Các chỉ số đang ở mức an toàn';
      case DashboardOverallStatus.warning:
        return 'Một số chỉ số cần chú ý hôm nay';
      case DashboardOverallStatus.critical:
        return 'Có chỉ số vượt ngưỡng an toàn cần theo dõi';
      case DashboardOverallStatus.noDevice:
        return 'Ghép nối thiết bị để xem dữ liệu sức khoẻ trực tiếp';
      case DashboardOverallStatus.offline:
        return 'Thiết bị đang ngoại tuyến hoặc chưa gửi dữ liệu mới';
    }
  }

  String _buildUpdatedLabel(
    BuildContext context, {
    required DateTime? updatedAt,
    required bool isStale,
    required bool hasAnyLoading,
    required bool hasActiveDevice,
    DeviceConnectionUiState? connectionState,
  }) {
    final resolvedConnectionState =
        connectionState ??
        resolveDashboardConnectionState(
          activeDevices: const [],
          isStale: isStale,
        );
    if (resolvedConnectionState == DeviceConnectionUiState.connected &&
        updatedAt != null &&
        isStale) {
      return 'Đang chờ mẫu mới từ ${_formatTime(context, updatedAt)}';
    }
    if (updatedAt != null && !isStale) {
      return 'Cập nhật lúc ${_formatTime(context, updatedAt)}';
    }
    if (hasAnyLoading) {
      return 'Đang tải dữ liệu sức khoẻ';
    }
    if (!hasActiveDevice) {
      return 'Chưa kết nối đồng hồ';
    }
    if (updatedAt != null) {
      return 'Mất kết nối từ ${_formatTime(context, updatedAt)}';
    }
    return 'Có thể đã mất kết nối';
  }

  String _buildSleepSummary(SleepSession? sleep) {
    if (sleep != null) {
      return '${sleep.qualityLabelVi} • ${sleep.sleepText}';
    }
    if (_sleepProvider.isLoading) {
      return 'Đang tải dữ liệu giấc ngủ';
    }
    if (_sleepProvider.hasError) {
      return 'Không thể tải dữ liệu giấc ngủ';
    }
    if (_sleepProvider.isNoDataYet || _sleepProvider.isEmpty) {
      return 'Chưa có dữ liệu giấc ngủ';
    }
    return 'Chưa có dữ liệu giấc ngủ';
  }

  String _resolveDisplayName(BuildContext context) {
    try {
      final authProvider = context.read<AuthProvider>();
      final fullName = authProvider.currentUser?.fullName.trim();
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }
    } catch (_) {
      // Fallback to a generic label when AuthProvider is not available.
    }
    return 'Người dùng';
  }

  VitalMetricItem _buildVitalItem({
    required BuildContext context,
    required VitalMetricType type,
    required String label,
    required String routeVitalType,
    required VitalSigns? vitals,
    required bool isStale,
    required DeviceConnectionUiState connectionState,
    String suffix = '',
  }) {
    final rawValue = _extractVitalValue(vitals, routeVitalType);
    final isEmpty = _isEmptyVitalValue(rawValue);
    final displayValue = _formatVitalValue(rawValue, suffix: suffix);
    final vitalStatus = _extractVitalStatus(vitals, routeVitalType);
    final shouldShowOfflineState =
        isStale && connectionState == DeviceConnectionUiState.offline;
    final isWaitingForFreshVitals =
        isStale && connectionState == DeviceConnectionUiState.connected;
    final statusLabel = shouldShowOfflineState
        ? 'Ngoại tuyến'
        : isWaitingForFreshVitals
        ? 'Chờ dữ liệu mới'
        : _dashboardProvider.state == VitalsUIState.loading && isEmpty
        ? 'Đang tải'
        : isEmpty
        ? 'Chưa có dữ liệu'
        : _statusLabel(vitalStatus);
    final visualState = shouldShowOfflineState
        ? VitalMetricVisualState.stale
        : isWaitingForFreshVitals
        ? VitalMetricVisualState.warning
        : _visualState(vitalStatus, isEmpty: isEmpty);

    return VitalMetricItem(
      type: type,
      label: label,
      value: displayValue,
      statusLabel: statusLabel,
      visualState: visualState,
      onTap: () {
        Navigator.pushNamed(
          context,
          '/vital-detail',
          arguments: {'vitalType': routeVitalType},
        );
      },
    );
  }

  String _statusLabel(VitalStatus status) {
    switch (status) {
      case VitalStatus.normal:
        return 'Bình thường';
      case VitalStatus.warning:
        return 'Chú ý';
      case VitalStatus.critical:
        return 'Cảnh báo';
      case VitalStatus.unknown:
        return 'Chưa có dữ liệu';
    }
  }

  VitalMetricVisualState _visualState(
    VitalStatus status, {
    required bool isEmpty,
  }) {
    if (isEmpty) {
      return VitalMetricVisualState.empty;
    }
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

  String _extractVitalValue(VitalSigns? vitals, String vitalType) {
    if (vitals == null) {
      return vitalType == 'bp' ? '--/--' : '--';
    }

    switch (vitalType) {
      case 'hr':
        return vitals.heartRate?.toStringAsFixed(0) ?? '--';
      case 'spo2':
        return vitals.spo2?.toStringAsFixed(1) ?? '--';
      case 'temp':
        return vitals.temperature?.toStringAsFixed(1) ?? '--';
      case 'bp':
        final sys = vitals.bloodPressureSys?.toStringAsFixed(0) ?? '--';
        final dia = vitals.bloodPressureDia?.toStringAsFixed(0) ?? '--';
        return '$sys/$dia';
      default:
        return '--';
    }
  }

  VitalStatus _extractVitalStatus(VitalSigns? vitals, String vitalType) {
    if (vitals == null) {
      return VitalStatus.unknown;
    }

    switch (vitalType) {
      case 'hr':
        return vitals.getHeartRateStatus();
      case 'spo2':
        return vitals.getSpo2Status();
      case 'temp':
        return vitals.getTemperatureStatus();
      case 'bp':
        final sysStatus = vitals.getBloodPressureSysStatus();
        final diaStatus = vitals.getBloodPressureDiaStatus();
        if (sysStatus == VitalStatus.critical ||
            diaStatus == VitalStatus.critical) {
          return VitalStatus.critical;
        }
        if (sysStatus == VitalStatus.warning ||
            diaStatus == VitalStatus.warning) {
          return VitalStatus.warning;
        }
        if (sysStatus == VitalStatus.unknown &&
            diaStatus == VitalStatus.unknown) {
          return VitalStatus.unknown;
        }
        return VitalStatus.normal;
      default:
        return VitalStatus.unknown;
    }
  }

  bool _isEmptyVitalValue(String value) {
    return value == '--' || value == '--/--';
  }

  String _formatVitalValue(String value, {String suffix = ''}) {
    if (_isEmptyVitalValue(value) || suffix.isEmpty) {
      return value;
    }
    return '$value$suffix';
  }

  String _formatTime(BuildContext context, DateTime timestamp) {
    return TimeOfDay.fromDateTime(timestamp.toLocal()).format(context);
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
