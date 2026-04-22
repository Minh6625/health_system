import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/routes/app_router.dart';
import '../../auth/services/token_storage_service.dart';
import '../repositories/emergency_caregiver_repository.dart';
import '../screens/sos_confirm_screen.dart';
import '../../family/models/family_profile_snapshot.dart';
import '../../family/widgets/family_sos_full_screen_overlay.dart';
import '../../notifications/models/notification_open_target.dart';
import '../../notifications/services/notification_event_mapper.dart';
import '../../notifications/services/notification_open_router.dart';
import '../../notifications/services/notification_runtime_service.dart';
import '../widgets/risk_alert_full_screen_overlay.dart';

Map<String, dynamic>? buildAndroidCriticalRiskLaunchPayload(
  Map<String, dynamic> rawData, {
  String? fallbackTitle,
  String? fallbackBody,
}) {
  return buildNotificationAndroidCriticalRiskLaunchPayload(
    rawData,
    fallbackTitle: fallbackTitle,
    fallbackBody: fallbackBody,
  );
}

RealtimeNotificationOpenTarget? parseAndroidCriticalRiskLaunchPayload(
  dynamic rawPayload,
) {
  return parseNotificationAndroidCriticalRiskLaunchPayload(rawPayload);
}

String? normalizeRealtimeRiskLevel(String? level) {
  return normalizeNotificationRiskLevel(level);
}

String resolveRealtimeRiskLevel(String? rawLevel, {required String alertType}) {
  return resolveNotificationRiskLevel(rawLevel, alertType: alertType);
}

typedef RealtimeNotificationOpenTarget = NotificationOpenTarget;

RealtimeNotificationOpenTarget? parseRealtimeNotificationOpenTarget(
  Map<String, dynamic> rawData,
) {
  return parseNotificationOpenTarget(rawData);
}

typedef RiskAlertTargetPresenter =
    Future<void> Function(RealtimeNotificationOpenTarget target);
typedef SosDetailNavigator = Future<void> Function(String sosId);
typedef NotificationsNavigator = Future<void> Function();
typedef CriticalAlertAuthRedirector =
    Future<void> Function(RealtimeNotificationOpenTarget target);
typedef RiskEscalationConfirmOpener = Future<void> Function(int recipientCount);
typedef AlertNotificationPresenter =
    Future<void> Function(Map<String, dynamic> item, {required String sosId});

class SOSRealtimeAlertService implements NotificationEmergencyAdapter {
  SOSRealtimeAlertService._internal({
    TokenStorageService? tokenStorageService,
    EmergencyCaregiverRepository? emergencyCaregiverRepository,
    FlutterLocalNotificationsPlugin? notifications,
    RiskAlertTargetPresenter? riskAlertTargetPresenter,
    SosDetailNavigator? sosDetailNavigator,
    NotificationsNavigator? notificationsNavigator,
    CriticalAlertAuthRedirector? criticalAlertAuthRedirector,
    RiskEscalationConfirmOpener? riskEscalationConfirmOpener,
    AlertNotificationPresenter? fullScreenAlertPresenter,
    AlertNotificationPresenter? missedAlertPresenter,
    Duration overlayVibrationInterval = _defaultOverlayVibrationInterval,
  }) : _tokenStorageService = tokenStorageService ?? TokenStorageService(),
       _emergencyCaregiverRepository =
           emergencyCaregiverRepository ?? EmergencyCaregiverRepository(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _riskAlertTargetPresenter = riskAlertTargetPresenter,
       _sosDetailNavigator = sosDetailNavigator,
       _notificationsNavigator = notificationsNavigator,
       _criticalAlertAuthRedirector = criticalAlertAuthRedirector,
       _riskEscalationConfirmOpener = riskEscalationConfirmOpener,
       _fullScreenAlertPresenter = fullScreenAlertPresenter,
       _missedAlertPresenter = missedAlertPresenter,
       _overlayVibrationInterval = overlayVibrationInterval;

  static final SOSRealtimeAlertService instance =
      SOSRealtimeAlertService._internal();

  @visibleForTesting
  factory SOSRealtimeAlertService.test({
    TokenStorageService? tokenStorageService,
    EmergencyCaregiverRepository? emergencyCaregiverRepository,
    FlutterLocalNotificationsPlugin? notifications,
    RiskAlertTargetPresenter? riskAlertTargetPresenter,
    SosDetailNavigator? sosDetailNavigator,
    NotificationsNavigator? notificationsNavigator,
    CriticalAlertAuthRedirector? criticalAlertAuthRedirector,
    RiskEscalationConfirmOpener? riskEscalationConfirmOpener,
    AlertNotificationPresenter? fullScreenAlertPresenter,
    AlertNotificationPresenter? missedAlertPresenter,
    Duration overlayVibrationInterval = _defaultOverlayVibrationInterval,
  }) {
    return SOSRealtimeAlertService._internal(
      tokenStorageService: tokenStorageService,
      emergencyCaregiverRepository: emergencyCaregiverRepository,
      notifications: notifications,
      riskAlertTargetPresenter: riskAlertTargetPresenter,
      sosDetailNavigator: sosDetailNavigator,
      notificationsNavigator: notificationsNavigator,
      criticalAlertAuthRedirector: criticalAlertAuthRedirector,
      riskEscalationConfirmOpener: riskEscalationConfirmOpener,
      fullScreenAlertPresenter: fullScreenAlertPresenter,
      missedAlertPresenter: missedAlertPresenter,
      overlayVibrationInterval: overlayVibrationInterval,
    );
  }

  static const String _fullScreenChannelId = 'sos_fullscreen_alerts';
  static const String _fullScreenChannelName = 'SOS Fullscreen Alerts';
  static const String _missedChannelId = 'sos_missed_alerts';
  static const String _missedChannelName = 'SOS Missed Alerts';

  // Risk alert notification channels (A7)
  static const String _riskChannelId = 'risk_alerts';
  static const String _riskChannelName = 'Risk Alerts';
  static const String _riskCriticalChannelId = 'risk_critical_alerts';
  static const String _riskCriticalChannelName = 'Risk Critical Alerts';

  static const Duration _defaultOverlayVibrationInterval = Duration(
    milliseconds: 420,
  );

  final TokenStorageService _tokenStorageService;
  final EmergencyCaregiverRepository _emergencyCaregiverRepository;
  final FlutterLocalNotificationsPlugin _notifications;
  final RiskAlertTargetPresenter? _riskAlertTargetPresenter;
  final SosDetailNavigator? _sosDetailNavigator;
  final NotificationsNavigator? _notificationsNavigator;
  final CriticalAlertAuthRedirector? _criticalAlertAuthRedirector;
  final RiskEscalationConfirmOpener? _riskEscalationConfirmOpener;
  final AlertNotificationPresenter? _fullScreenAlertPresenter;
  final AlertNotificationPresenter? _missedAlertPresenter;
  final Duration _overlayVibrationInterval;

  Timer? _overlayVibrationTimer;

  GlobalKey<NavigatorState>? _navigatorKey;

  final Map<String, DateTime> _recentAlertPresentation = {};
  String? _lastOpenedSosId;
  DateTime? _lastOpenedSosAt;
  String? _lastOpenedAlertSosId;
  DateTime? _lastOpenedAlertAt;
  bool _isAlertOverlayVisible = false;
  Future<void> Function(NotificationOpenTarget target)?
  _notificationRuntimeCriticalAlertRedirector;

  FlutterLocalNotificationsPlugin get notificationsPlugin => _notifications;

  void bindNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  void bindNotificationRuntimeCriticalAlertRedirector(
    Future<void> Function(NotificationOpenTarget target) redirector,
  ) {
    _notificationRuntimeCriticalAlertRedirector = redirector;
  }

  @override
  Future<void> openNotifications() {
    return _navigateToNotificationsScreen();
  }

  @override
  Future<void> openSosDetail(String sosId) {
    return _navigateToSosDetail(sosId);
  }

  @override
  Future<void> presentCriticalRiskTarget(NotificationOpenTarget target) {
    return _presentCriticalRiskTarget(target);
  }

  @override
  Future<void> presentFullscreenAlert(
    Map<String, dynamic> item, {
    required String subjectId,
  }) async {
    await _showFullScreenAlert(item, sosId: subjectId);

    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    if (_isRiskAlertType(alertType)) {
      return;
    }

    await _navigateToEmergencyAlertScreen(
      sosId: subjectId,
      title: (item['title'] as String?) ?? 'Canh bao khan cap',
      message:
          (item['message'] as String?) ??
          'Phat hien tinh huong khan cap. Nhan de xem chi tiet.',
    );
  }

  @override
  Future<void> presentMissedAlert(
    Map<String, dynamic> item, {
    required String subjectId,
  }) {
    return _showMissedAlert(item, sosId: subjectId);
  }

  @override
  Future<void> redirectCriticalAlertToAuth(NotificationOpenTarget target) async {
    if (_criticalAlertAuthRedirector != null) {
      await _criticalAlertAuthRedirector(target);
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      return;
    }

    navigatorState.pushNamedAndRemoveUntil(AppRouter.start, (_) => false);
  }

  @visibleForTesting
  Future<void> openRiskEscalationConfirmScreenForTest({
    required int recipientCount,
  }) {
    return _openRiskEscalationConfirmScreen(recipientCount: recipientCount);
  }

  @visibleForTesting
  bool looksLikeAuthFailureForTest(Object error) {
    return _looksLikeAuthFailure(error);
  }

  @visibleForTesting
  int extractRecipientCountForTest(Map<String, dynamic> response) {
    return _extractRecipientCount(response);
  }

  String _buildCriticalRiskLaunchDedupeKey(String notificationId) {
    return 'critical-launch:$notificationId';
  }

  Future<void> _presentCriticalRiskTarget(
    RealtimeNotificationOpenTarget target,
  ) async {
    final notificationId = target.notificationId?.trim();
    if (notificationId == null || notificationId.isEmpty) {
      return;
    }

    final dedupeKey = _buildCriticalRiskLaunchDedupeKey(notificationId);
    if (_wasAlertPresentedRecently(dedupeKey)) {
      return;
    }

    _rememberPresentedAlert(dedupeKey);

    if (_riskAlertTargetPresenter != null) {
      await _riskAlertTargetPresenter(target);
      return;
    }

    await _navigateToRiskAlertScreen(
      notificationId: notificationId,
      alertType: target.alertType ?? 'risk_critical',
      riskLevel: target.riskLevel ?? 'critical',
      title: target.title ?? '🚨 Cảnh báo sức khỏe khẩn cấp',
      message:
          target.message ??
          'Phát hiện chỉ số sức khỏe bất thường. Nhấn để xem.',
      riskScoreId: target.riskScoreId,
    );
  }

  Future<void> _navigateToSosDetail(String sosId) async {
    final now = DateTime.now().toUtc();
    if (_lastOpenedSosId == sosId &&
        _lastOpenedSosAt != null &&
        now.difference(_lastOpenedSosAt!).inSeconds < 2) {
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      return;
    }

    _lastOpenedSosId = sosId;
    _lastOpenedSosAt = now;

    if (_sosDetailNavigator != null) {
      await _sosDetailNavigator(sosId);
      return;
    }

    navigatorState.pushNamed(
      AppRouter.emergencySosDetail,
      arguments: {'sosId': sosId},
    );
  }

  Future<void> _navigateToNotificationsScreen() async {
    if (_notificationsNavigator != null) {
      await _notificationsNavigator();
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      return;
    }

    navigatorState.pushNamed(AppRouter.notifications);
  }

  Future<void> _navigateToEmergencyAlertScreen({
    required String sosId,
    required String title,
    required String message,
  }) async {
    final now = DateTime.now().toUtc();
    if (_lastOpenedAlertSosId == sosId &&
        _lastOpenedAlertAt != null &&
        now.difference(_lastOpenedAlertAt!).inSeconds < 2) {
      return;
    }

    if (_isAlertOverlayVisible) {
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      return;
    }

    final overlayContext = navigatorState.overlay?.context;
    if (overlayContext == null) {
      return;
    }

    _lastOpenedAlertSosId = sosId;
    _lastOpenedAlertAt = now;
    _isAlertOverlayVisible = true;

    final profileSnapshot = FamilyProfileSnapshot(
      id: sosId,
      sosId: sosId,
      name: _extractPatientNameFromTitle(title),
      relation: 'Canh bao khan cap',
      isSosActive: true,
      lastUpdated: now,
      specialNote: message,
    );

    try {
      _startOverlayVibrationPulse();
      await showGeneralDialog<void>(
        context: overlayContext,
        barrierDismissible: false,
        barrierLabel: 'SOS Alert',
        barrierColor: Colors.transparent,
        pageBuilder: (dialogContext, _, _) {
          return FamilySOSFullScreenOverlay(
            sosProfiles: [profileSnapshot],
            onViewDetail: (selectedSosId) {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              unawaited(_navigateToSosDetail(selectedSosId));
            },
            onDismiss: () {
              Navigator.of(dialogContext, rootNavigator: true).pop();
            },
          );
        },
      );
    } finally {
      _stopOverlayVibrationPulse();
      _isAlertOverlayVisible = false;
    }
  }

  /// Navigate to the risk alert fullscreen overlay (A7).
  Future<void> _navigateToRiskAlertScreen({
    required String notificationId,
    required String alertType,
    required String riskLevel,
    required String title,
    required String message,
    int? riskScoreId,
  }) async {
    final now = DateTime.now().toUtc();
    if (_lastOpenedAlertSosId == notificationId &&
        _lastOpenedAlertAt != null &&
        now.difference(_lastOpenedAlertAt!).inSeconds < 2) {
      return;
    }

    if (_isAlertOverlayVisible) {
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      return;
    }

    final overlayContext = navigatorState.overlay?.context;
    if (overlayContext == null) {
      return;
    }

    _lastOpenedAlertSosId = notificationId;
    _lastOpenedAlertAt = now;
    _isAlertOverlayVisible = true;
    final alertTarget = RealtimeNotificationOpenTarget(
      type: 'risk',
      notificationId: notificationId,
      alertType: alertType,
      riskLevel: riskLevel,
      riskScoreId: riskScoreId,
      title: title,
      message: message,
    );

    try {
      _startOverlayVibrationPulse();
      await showGeneralDialog<void>(
        context: overlayContext,
        barrierDismissible: false,
        barrierLabel: 'Risk Alert',
        barrierColor: Colors.transparent,
        pageBuilder: (dialogContext, _, _) {
          return RiskAlertFullScreenOverlay(
            title: title,
            message: message,
            riskLevel: riskLevel,
            alertType: alertType,
            notificationId: notificationId,
            onConfirmOk: () async {
              await _handleRiskSafeAcknowledgement(
                dialogContext: dialogContext,
                target: alertTarget,
              );
            },
            onRequestHelp: () async {
              await _handleRiskEscalationAcknowledgement(
                dialogContext: dialogContext,
                target: alertTarget,
                responseType: 'help_requested',
              );
            },
            onTimeoutEscalated: () async {
              await _handleRiskEscalationAcknowledgement(
                dialogContext: dialogContext,
                target: alertTarget,
                responseType: 'timeout_escalated',
              );
            },
            onDismiss: () async {
              await _dismissRiskAlert(dialogContext);
            },
          );
        },
      );
    } finally {
      _stopOverlayVibrationPulse();
      _isAlertOverlayVisible = false;
    }
  }

  Future<void> _handleRiskSafeAcknowledgement({
    required BuildContext dialogContext,
    required RealtimeNotificationOpenTarget target,
  }) async {
    if (!await _canSubmitCriticalRiskResponse()) {
      if (!dialogContext.mounted) {
        return;
      }
      await _closeDialogAndRedirectCriticalAlertToAuth(
        dialogContext: dialogContext,
        target: target,
      );
      return;
    }

    try {
      await _submitRiskResponse(
        notificationId: target.notificationId ?? '',
        responseType: 'safe',
        source: 'overlay',
        riskScoreId: target.riskScoreId,
      );
    } catch (e) {
      if (_handleRiskResponseAuthFailure(e)) {
        if (!dialogContext.mounted) {
          return;
        }
        await _closeDialogAndRedirectCriticalAlertToAuth(
          dialogContext: dialogContext,
          target: target,
        );
        return;
      }
      rethrow;
    }

    if (!dialogContext.mounted) {
      return;
    }

    Navigator.of(dialogContext, rootNavigator: true).pop();
  }

  Future<void> _handleRiskEscalationAcknowledgement({
    required BuildContext dialogContext,
    required RealtimeNotificationOpenTarget target,
    required String responseType,
  }) async {
    if (!await _canSubmitCriticalRiskResponse()) {
      if (!dialogContext.mounted) {
        return;
      }
      await _closeDialogAndRedirectCriticalAlertToAuth(
        dialogContext: dialogContext,
        target: target,
      );
      return;
    }

    late final Map<String, dynamic> response;
    try {
      response = await _submitRiskResponse(
        notificationId: target.notificationId ?? '',
        responseType: responseType,
        source: 'overlay',
        riskScoreId: target.riskScoreId,
      );
    } catch (e) {
      if (_handleRiskResponseAuthFailure(e)) {
        if (!dialogContext.mounted) {
          return;
        }
        await _closeDialogAndRedirectCriticalAlertToAuth(
          dialogContext: dialogContext,
          target: target,
        );
        return;
      }
      rethrow;
    }

    if (!dialogContext.mounted) {
      return;
    }

    Navigator.of(dialogContext, rootNavigator: true).pop();

    final recipientCount = _extractRecipientCount(response);
    await _openRiskEscalationConfirmScreen(recipientCount: recipientCount);
  }

  Future<void> _dismissRiskAlert(BuildContext dialogContext) async {
    if (!dialogContext.mounted) {
      return;
    }

    Navigator.of(dialogContext, rootNavigator: true).pop();
  }

  Future<Map<String, dynamic>> _submitRiskResponse({
    required String notificationId,
    required String responseType,
    required String source,
    int? riskScoreId,
  }) async {
    try {
      return await _emergencyCaregiverRepository.respondToRiskNotification(
        notificationId: notificationId,
        responseType: responseType,
        source: source,
        riskScoreId: riskScoreId,
      );
    } catch (e) {
      debugPrint('Failed to submit risk response: $e');
      rethrow;
    }
  }

  Future<bool> _canSubmitCriticalRiskResponse() async {
    final token = await _tokenStorageService.readAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  bool _looksLikeAuthFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('not authenticated') ||
        message.contains('đăng nhập') ||
        message.contains('login');
  }

  bool _handleRiskResponseAuthFailure(Object error) {
    return _looksLikeAuthFailure(error);
  }

  Future<void> _closeDialogAndRedirectCriticalAlertToAuth({
    required BuildContext dialogContext,
    required RealtimeNotificationOpenTarget target,
  }) async {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
    final runtimeRedirector = _notificationRuntimeCriticalAlertRedirector;
    if (runtimeRedirector != null) {
      await runtimeRedirector(target);
      return;
    }
    await redirectCriticalAlertToAuth(target);
  }

  int _extractRecipientCount(Map<String, dynamic> response) {
    final candidates = <Object?>[
      response['recipient_count'],
      response['recipients_count'],
      response['recipientCount'],
      response['escalated_count'],
      response['helper_count'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final parsed = int.tryParse(candidate.toString());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return 1;
  }

  Future<void> _openRiskEscalationConfirmScreen({
    required int recipientCount,
  }) async {
    if (_riskEscalationConfirmOpener != null) {
      await _riskEscalationConfirmOpener(recipientCount);
      return;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      return;
    }

    navigatorState.push(
      MaterialPageRoute(
        builder: (_) => SosConfirmScreen(
          recipientCount: recipientCount,
          mode: SosConfirmMode.riskEscalation,
        ),
      ),
    );
  }

  void _startOverlayVibrationPulse() {
    _stopOverlayVibrationPulse();
    unawaited(_triggerOverlayVibrationBurst());

    _overlayVibrationTimer = Timer.periodic(_overlayVibrationInterval, (_) {
      unawaited(_triggerOverlayVibrationBurst());
    });
  }

  void _stopOverlayVibrationPulse() {
    _overlayVibrationTimer?.cancel();
    _overlayVibrationTimer = null;
  }

  Future<void> _triggerOverlayVibrationBurst() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    HapticFeedback.vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    HapticFeedback.heavyImpact();
  }

  String _extractPatientNameFromTitle(String title) {
    final index = title.indexOf(':');
    if (index >= 0 && index < title.length - 1) {
      final value = title.substring(index + 1).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    final trimmed = title.trim();
    return trimmed.isEmpty ? 'Nguoi than' : trimmed;
  }

  /// Returns true for any risk_* alert types.
  bool _isRiskAlertType(String alertType) {
    return isRiskAlertType(alertType);
  }

  String _resolveRiskLevel(String? rawLevel, {required String alertType}) {
    return resolveRealtimeRiskLevel(rawLevel, alertType: alertType);
  }

  bool _wasAlertPresentedRecently(String key) {
    final now = DateTime.now().toUtc();
    _recentAlertPresentation.removeWhere(
      (_, time) => now.difference(time).inMinutes >= 5,
    );

    final presentedAt = _recentAlertPresentation[key];
    if (presentedAt == null) {
      return false;
    }
    return now.difference(presentedAt).inMinutes < 5;
  }

  void _rememberPresentedAlert(String key) {
    _recentAlertPresentation[key] = DateTime.now().toUtc();
  }

  Map<String, dynamic> _toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic val) => MapEntry(key.toString(), val),
      );
    }
    return <String, dynamic>{};
  }

  Future<void> _showFullScreenAlert(
    Map<String, dynamic> item, {
    required String sosId,
  }) async {
    if (_fullScreenAlertPresenter != null) {
      await _fullScreenAlertPresenter(item, sosId: sosId);
      return;
    }

    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    final isRisk = _isRiskAlertType(alertType);
    final riskLevel = isRisk
        ? _resolveRiskLevel(
            _toMap(item['data'])['risk_level']?.toString(),
            alertType: alertType,
          )
        : null;

    final title = (item['title'] as String?) ?? 'Cảnh báo khẩn cấp';
    final body =
        (item['message'] as String?) ??
        'Phát hiện tình huống khẩn cấp. Nhấn để xem chi tiết.';

    final payload = jsonEncode({
      'type': isRisk ? 'risk' : 'sos',
      if (!isRisk) 'sosId': sosId,
      if (isRisk) 'alertType': alertType,
      if (isRisk) 'alert_type': alertType,
      if (isRisk) 'riskLevel': riskLevel ?? 'medium',
      if (isRisk) 'risk_level': riskLevel ?? 'medium',
      if (isRisk)
        'riskScoreId': _toMap(item['data'])['risk_score_id']?.toString(),
      if (isRisk)
        'risk_score_id': _toMap(item['data'])['risk_score_id']?.toString(),
      'notificationId': item['id']?.toString(),
      'notification_id': item['id']?.toString(),
      'title': title,
      'body': body,
      'message': body,
    });

    // Use risk-specific channel for risk alerts.
    final channelId = isRisk
        ? (riskLevel == 'critical' ? _riskCriticalChannelId : _riskChannelId)
        : _fullScreenChannelId;
    final channelName = isRisk
        ? (riskLevel == 'critical'
              ? _riskCriticalChannelName
              : _riskChannelName)
        : _fullScreenChannelName;
    final channelDesc = isRisk
        ? 'Cảnh báo chỉ số sức khỏe bất thường'
        : 'Cảnh báo SOS và té ngã toàn màn hình';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 900, 400, 900, 400, 1400]),
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: true,
      ),
    );

    final idSeed =
        item['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    final notificationId = 100000 + (idSeed.abs() % 900000);

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _showMissedAlert(
    Map<String, dynamic> item, {
    required String sosId,
  }) async {
    if (_missedAlertPresenter != null) {
      await _missedAlertPresenter(item, sosId: sosId);
      return;
    }

    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    final isRisk = _isRiskAlertType(alertType);
    final riskLevel = isRisk
        ? _resolveRiskLevel(
            _toMap(item['data'])['risk_level']?.toString(),
            alertType: alertType,
          )
        : null;

    final title =
        (item['title'] as String?) ??
        (isRisk ? 'Cảnh báo sức khỏe bỏ lỡ' : 'Cảnh báo SOS bỏ lỡ');
    final body =
        (item['message'] as String?) ??
        (isRisk
            ? 'Bạn có cảnh báo sức khỏe khi chưa hoạt động trong ứng dụng.'
            : 'Bạn có một cảnh báo SOS khi chưa hoạt động trong ứng dụng.');

    final payload = jsonEncode({
      'type': isRisk ? 'risk' : 'sos',
      if (!isRisk) 'sosId': sosId,
      if (isRisk) 'alertType': alertType,
      if (isRisk) 'riskLevel': riskLevel ?? 'medium',
      if (isRisk)
        'riskScoreId': _toMap(item['data'])['risk_score_id']?.toString(),
      'notificationId': item['id']?.toString(),
    });

    final missedChannelId = isRisk ? _riskChannelId : _missedChannelId;
    final missedChannelName = isRisk ? _riskChannelName : _missedChannelName;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        missedChannelId,
        missedChannelName,
        channelDescription: isRisk
            ? 'Cảnh báo sức khỏe bỏ lỡ'
            : 'Thông báo SOS bị bỏ lỡ khi không online',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        playSound: false,
        enableVibration: false,
        visibility: NotificationVisibility.private,
        autoCancel: true,
      ),
    );

    final idSeed =
        item['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    final notificationId = 200000 + (idSeed.abs() % 900000);

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> dispose() async {
    _stopOverlayVibrationPulse();
  }
}
