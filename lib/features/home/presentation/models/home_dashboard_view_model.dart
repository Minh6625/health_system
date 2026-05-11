import '../widgets/health_status_hero_card.dart' show DashboardOverallStatus;
import '../widgets/connection_status_strip.dart' show DeviceConnectionUiState;
import '../../../../shared/presentation/emergency/emergency_sticky_bar.dart'
    show EmergencyBarEmphasis;
import '../widgets/vital_metric_card.dart' show VitalMetricItem;
import '../widgets/risk_insight_card.dart' show RiskVisualState;

class HomeDashboardViewModel {
  final Future<void> Function() onRefresh;

  // Header
  final String displayName;
  final String? avatarUrl;
  final String latestUpdatedLabel;

  // Hero Card
  final DashboardOverallStatus overallStatus;
  final String heroTitle;
  final String heroSummary;
  final bool showCallHelpCta;

  // Connection
  final DeviceConnectionUiState deviceConnectionState;
  final int? batteryPercent;

  // Banners
  final bool isOffline;
  final bool hasWarningBanner;
  final bool hasError;
  final String? errorMessage;

  // Vitals
  final List<VitalMetricItem> vitalItems;

  // Sleep
  final String sleepDurationLabel;
  final int sleepDurationMinutes;
  final String sleepInsightSummary;

  // Risk
  final String riskScoreLabel;
  final String riskLevelLabel;
  final String riskSummary;
  final RiskVisualState riskVisualState;

  // Shell Badges
  final bool familyHasAlertBadge;
  final bool deviceNeedsAttention;
  final EmergencyBarEmphasis emergencyBarEmphasis;

  HomeDashboardViewModel({
    required this.onRefresh,
    required this.displayName,
    this.avatarUrl,
    required this.latestUpdatedLabel,
    required this.overallStatus,
    required this.heroTitle,
    required this.heroSummary,
    this.showCallHelpCta = false,
    required this.deviceConnectionState,
    this.batteryPercent,
    this.isOffline = false,
    this.hasWarningBanner = false,
    this.hasError = false,
    this.errorMessage,
    required this.vitalItems,
    required this.sleepDurationLabel,
    required this.sleepDurationMinutes,
    required this.sleepInsightSummary,
    required this.riskScoreLabel,
    required this.riskLevelLabel,
    required this.riskSummary,
    required this.riskVisualState,
    this.familyHasAlertBadge = false,
    this.deviceNeedsAttention = false,
    this.emergencyBarEmphasis = EmergencyBarEmphasis.defaultLevel,
  });
}
