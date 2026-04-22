import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routes/app_router.dart';
import '../../auth/services/token_storage_service.dart';
import '../repositories/emergency_caregiver_repository.dart';
import '../screens/sos_confirm_screen.dart';
import '../../family/models/family_profile_snapshot.dart';
import '../../family/widgets/family_sos_full_screen_overlay.dart';
import '../../notifications/models/notification_open_target.dart';
import '../../notifications/services/notification_open_router.dart';
import '../widgets/risk_alert_full_screen_overlay.dart';

const String _androidCriticalAlertChannel =
    'healthguard/emergency/critical_alert';
const String _androidOnCriticalAlertLaunchMethod = 'onCriticalAlertLaunch';
const String _androidConsumePendingCriticalAlertLaunchMethod =
    'consumePendingCriticalAlertLaunch';
const String _androidDefaultNotificationIcon = '@mipmap/ic_launcher';
const String _backgroundRiskCriticalChannelId = 'risk_critical_alerts';
const String _backgroundRiskCriticalChannelName = 'Risk Critical Alerts';

final FlutterLocalNotificationsPlugin _backgroundNotifications =
    FlutterLocalNotificationsPlugin();
bool _backgroundNotificationsInitialized = false;

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

int _deriveCriticalRiskNotificationId(String notificationId) {
  return 300000 + (notificationId.hashCode.abs() % 600000);
}

Future<void> _initializeBackgroundNotifications() async {
  if (_backgroundNotificationsInitialized) {
    return;
  }

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings(_androidDefaultNotificationIcon),
  );
  await _backgroundNotifications.initialize(initSettings);

  final androidPlugin = _backgroundNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _backgroundRiskCriticalChannelId,
      _backgroundRiskCriticalChannelName,
      description: 'Cảnh báo chỉ số sức khỏe nguy hiểm',
      importance: Importance.max,
    ),
  );

  _backgroundNotificationsInitialized = true;
}

Future<void> _showBackgroundCriticalRiskNotification(
  RemoteMessage message,
) async {
  final payload = buildAndroidCriticalRiskLaunchPayload(
    message.data,
    fallbackTitle: message.notification?.title,
    fallbackBody: message.notification?.body,
  );
  if (payload == null) {
    return;
  }

  await _initializeBackgroundNotifications();

  final notificationId = _deriveCriticalRiskNotificationId(
    payload['notificationId'].toString(),
  );
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _backgroundRiskCriticalChannelId,
      _backgroundRiskCriticalChannelName,
      channelDescription: 'Cảnh báo chỉ số sức khỏe nguy hiểm',
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

  await _backgroundNotifications.show(
    notificationId,
    payload['title']?.toString(),
    payload['body']?.toString(),
    details,
    payload: jsonEncode(payload),
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  await _showBackgroundCriticalRiskNotification(message);
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

class SOSRealtimeAlertService {
  SOSRealtimeAlertService._internal({
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    EmergencyCaregiverRepository? emergencyCaregiverRepository,
    FlutterSecureStorage? storage,
    FlutterLocalNotificationsPlugin? notifications,
    MethodChannel? androidCriticalAlertBridge,
    RiskAlertTargetPresenter? riskAlertTargetPresenter,
    SosDetailNavigator? sosDetailNavigator,
    NotificationsNavigator? notificationsNavigator,
    CriticalAlertAuthRedirector? criticalAlertAuthRedirector,
    RiskEscalationConfirmOpener? riskEscalationConfirmOpener,
    AlertNotificationPresenter? fullScreenAlertPresenter,
    AlertNotificationPresenter? missedAlertPresenter,
    Duration overlayVibrationInterval = _defaultOverlayVibrationInterval,
  }) : _apiClient = apiClient ?? ApiClient(),
       _tokenStorageService = tokenStorageService ?? TokenStorageService(),
       _emergencyCaregiverRepository =
           emergencyCaregiverRepository ?? EmergencyCaregiverRepository(),
       _storage = storage ?? const FlutterSecureStorage(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _androidCriticalAlertBridge =
           androidCriticalAlertBridge ??
           const MethodChannel(_androidCriticalAlertChannel),
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
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    EmergencyCaregiverRepository? emergencyCaregiverRepository,
    FlutterSecureStorage? storage,
    FlutterLocalNotificationsPlugin? notifications,
    MethodChannel? androidCriticalAlertBridge,
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
      apiClient: apiClient,
      tokenStorageService: tokenStorageService,
      emergencyCaregiverRepository: emergencyCaregiverRepository,
      storage: storage,
      notifications: notifications,
      androidCriticalAlertBridge: androidCriticalAlertBridge,
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

  static const String _lastSeenAtKey = 'sos_last_seen_alert_created_at';
  static const String _lastPresentedIdKey =
      'sos_last_presented_notification_id';
  static const String _registeredPushTokenKey = 'sos_registered_push_token';
  static const Duration _reLoginRingingWindow = Duration(hours: 1);
  static const Duration _defaultOverlayVibrationInterval = Duration(
    milliseconds: 420,
  );

  final ApiClient _apiClient;
  final TokenStorageService _tokenStorageService;
  final EmergencyCaregiverRepository _emergencyCaregiverRepository;
  final FlutterSecureStorage _storage;
  final FlutterLocalNotificationsPlugin _notifications;
  final MethodChannel _androidCriticalAlertBridge;
  final RiskAlertTargetPresenter? _riskAlertTargetPresenter;
  final SosDetailNavigator? _sosDetailNavigator;
  final NotificationsNavigator? _notificationsNavigator;
  final CriticalAlertAuthRedirector? _criticalAlertAuthRedirector;
  final RiskEscalationConfirmOpener? _riskEscalationConfirmOpener;
  final AlertNotificationPresenter? _fullScreenAlertPresenter;
  final AlertNotificationPresenter? _missedAlertPresenter;
  final Duration _overlayVibrationInterval;

  FirebaseMessaging? _messaging;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;
  StreamSubscription<RemoteMessage>? _fcmOpenedAppSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  Timer? _reconnectTimer;
  Timer? _pushTokenRetryTimer;
  Timer? _overlayVibrationTimer;

  GlobalKey<NavigatorState>? _navigatorKey;

  bool _isInitialized = false;
  bool _isFcmInitialized = false;
  bool _isRealtimeEnabled = false;
  bool _isConnecting = false;
  bool _isSyncingPushToken = false;
  bool _pendingPushTokenSync = false;
  bool _androidCriticalAlertBridgeInitialized = false;
  int _pushTokenRetryAttempt = 0;
  String? _lastPresentedNotificationId;
  String? _currentFcmToken;
  bool? _hasFullScreenIntentPermission;
  String _activeStorageScope = 'signed_out';
  final Map<String, DateTime> _recentAlertPresentation = {};
  String? _lastOpenedSosId;
  DateTime? _lastOpenedSosAt;
  String? _lastOpenedAlertSosId;
  DateTime? _lastOpenedAlertAt;
  bool _isAlertOverlayVisible = false;
  RealtimeNotificationOpenTarget? _pendingCriticalAlertAfterAuth;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;
    if (_isInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await _ensureAndroidAlertPermissions(requestFullScreenIntent: true);

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _fullScreenChannelId,
        _fullScreenChannelName,
        description: 'Cảnh báo SOS và té ngã toàn màn hình',
        importance: Importance.max,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _missedChannelId,
        _missedChannelName,
        description: 'Thông báo SOS bị bỏ lỡ khi không online',
        importance: Importance.high,
      ),
    );

    // Risk alert channels (A7)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _riskChannelId,
        _riskChannelName,
        description: 'Cảnh báo chỉ số sức khỏe bất thường',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _riskCriticalChannelId,
        _riskCriticalChannelName,
        description: 'Cảnh báo chỉ số sức khỏe nguy hiểm',
        importance: Importance.max,
      ),
    );

    _lastPresentedNotificationId = null;

    await _initializeAndroidCriticalAlertBridge();
    await _initializeFcm();
    _isInitialized = true;
  }

  Future<void> _initializeFcm() async {
    if (_isFcmInitialized || kIsWeb) {
      return;
    }

    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;

      await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _currentFcmToken = await _messaging!.getToken();
      debugPrint('FCM initialized: token=${_describeToken(_currentFcmToken)}');

      _fcmTokenRefreshSubscription = _messaging!.onTokenRefresh.listen((token) {
        _currentFcmToken = token;
        debugPrint('FCM token refreshed: token=${_describeToken(token)}');
        if (_isRealtimeEnabled) {
          unawaited(_requestPushTokenSync(immediate: true));
        }
      });

      _fcmForegroundSubscription = FirebaseMessaging.onMessage.listen((
        message,
      ) {
        unawaited(_handleFcmForegroundMessage(message));
      });

      _fcmOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        message,
      ) {
        unawaited(_handleRemoteMessageOpen(message.data));
      });

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_handleRemoteMessageOpen(initialMessage.data));
      }

      _isFcmInitialized = true;
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
  }

  Future<void> _initializeAndroidCriticalAlertBridge() async {
    if (_androidCriticalAlertBridgeInitialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _androidCriticalAlertBridge.setMethodCallHandler((call) async {
      if (call.method != _androidOnCriticalAlertLaunchMethod) {
        return;
      }

      await _handleAndroidCriticalAlertLaunch(call.arguments);
    });

    try {
      final pendingPayload = await _androidCriticalAlertBridge
          .invokeMethod<String>(
            _androidConsumePendingCriticalAlertLaunchMethod,
          );
      if (pendingPayload != null && pendingPayload.trim().isNotEmpty) {
        await _handleAndroidCriticalAlertLaunch(pendingPayload);
      }
    } catch (e) {
      debugPrint('Android critical alert bridge init skipped: $e');
    }

    _androidCriticalAlertBridgeInitialized = true;
  }

  Future<void> _handleAndroidCriticalAlertLaunch(dynamic rawPayload) async {
    final target = parseAndroidCriticalRiskLaunchPayload(rawPayload);
    if (target == null) {
      return;
    }

    await _presentCriticalRiskTarget(target);
  }

  Future<void> onAuthStateChanged({required bool isAuthenticated}) async {
    if (!_isInitialized) {
      return;
    }

    if (isAuthenticated == _isRealtimeEnabled) {
      return;
    }

    _isRealtimeEnabled = isAuthenticated;

    if (!_isRealtimeEnabled) {
      _activeStorageScope = 'signed_out';
      _lastPresentedNotificationId = null;
      _recentAlertPresentation.clear();
      await _requestPushTokenSync(immediate: true);
      await _stopRealtime();
      return;
    }

    await _ensureAndroidAlertPermissions(requestFullScreenIntent: true);
    await _refreshStorageScopeFromAccessToken();
    await _initializeFcm();
    await _requestPushTokenSync(immediate: true);
    await _dispatchMissedAlertsOnReLogin();
    await _connectWebSocket();
    await _restorePendingCriticalAlertAfterAuth();
  }

  @visibleForTesting
  Future<void> handleRemoteMessageOpenForTest(Map<String, dynamic> data) {
    return _handleRemoteMessageOpen(data);
  }

  @visibleForTesting
  Future<void> handleAndroidCriticalAlertLaunchForTest(dynamic rawPayload) {
    return _handleAndroidCriticalAlertLaunch(rawPayload);
  }

  @visibleForTesting
  Future<void> processNotificationEventForTest(
    Map<String, dynamic> item, {
    required bool preferFullscreen,
  }) {
    return _processNotificationEvent(item, preferFullscreen: preferFullscreen);
  }

  @visibleForTesting
  Future<void> redirectCriticalAlertToAuthForTest(
    RealtimeNotificationOpenTarget target,
  ) {
    return _redirectCriticalAlertToAuth(target);
  }

  @visibleForTesting
  Future<void> restorePendingCriticalAlertAfterAuthForTest() {
    return _restorePendingCriticalAlertAfterAuth();
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

  @visibleForTesting
  RealtimeNotificationOpenTarget? get pendingCriticalAlertForTest =>
      _pendingCriticalAlertAfterAuth;

  @visibleForTesting
  void setRealtimeEnabledForTest(bool value) {
    _isRealtimeEnabled = value;
  }

  Future<void> _ensureAndroidAlertPermissions({
    required bool requestFullScreenIntent,
  }) async {
    if (kIsWeb) {
      return;
    }

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return;
    }

    try {
      final notificationsGranted = await androidPlugin
          .requestNotificationsPermission();
      debugPrint(
        'SOS notifications permission: ${notificationsGranted ?? false}',
      );
    } catch (e) {
      debugPrint('SOS notifications permission request skipped: $e');
    }

    if (!requestFullScreenIntent) {
      return;
    }

    try {
      final hasFullScreenPermission = await androidPlugin
          .requestFullScreenIntentPermission();
      _hasFullScreenIntentPermission = hasFullScreenPermission;
      debugPrint(
        'SOS full-screen intent permission: ${hasFullScreenPermission ?? false}',
      );
    } catch (e) {
      debugPrint('SOS full-screen intent permission request skipped: $e');
    }
  }

  Future<void> _refreshStorageScopeFromAccessToken() async {
    final token = await _tokenStorageService.readAccessToken();
    _activeStorageScope = _resolveStorageScopeFromAccessToken(token);
    _lastPresentedNotificationId = await _storage.read(
      key: _scopedStorageKey(_lastPresentedIdKey),
    );
  }

  String _scopedStorageKey(String baseKey) {
    return '$baseKey::$_activeStorageScope';
  }

  String _resolveStorageScopeFromAccessToken(String? token) {
    if (token == null || token.trim().isEmpty) {
      return 'unknown';
    }

    final parts = token.split('.');
    if (parts.length >= 2) {
      try {
        final normalized = base64Url.normalize(parts[1]);
        final payloadRaw = utf8.decode(base64Url.decode(normalized));
        final payload = jsonDecode(payloadRaw);
        if (payload is Map) {
          final map = payload.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          );

          final userId =
              map['user_id'] ?? map['sub'] ?? map['uid'] ?? map['id'];
          if (userId != null) {
            final value = userId.toString().trim();
            if (value.isNotEmpty) {
              return 'uid:$value';
            }
          }
        }
      } catch (_) {
        // Fall back to token fingerprint scope.
      }
    }

    final fingerprint = _stableTokenFingerprint(token);
    return 'token:$fingerprint';
  }

  String _stableTokenFingerprint(String token) {
    var hash = 0x811C9DC5;
    for (final unit in token.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final value = hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    return value;
  }

  String _describeToken(String? token) {
    final normalized = token?.trim();
    if (normalized == null || normalized.isEmpty) {
      return '<empty>';
    }
    if (normalized.length <= 24) {
      return normalized;
    }
    return '${normalized.substring(0, 24)}...';
  }

  Future<void> _requestPushTokenSync({bool immediate = false}) async {
    if (kIsWeb) {
      return;
    }

    _pendingPushTokenSync = true;
    if (immediate) {
      _pushTokenRetryTimer?.cancel();
      _pushTokenRetryTimer = null;
    }

    await _drainPushTokenSyncQueue();
  }

  Future<void> _drainPushTokenSyncQueue() async {
    if (_isSyncingPushToken || !_pendingPushTokenSync) {
      return;
    }

    _isSyncingPushToken = true;
    _pendingPushTokenSync = false;

    try {
      final success = await _syncPushTokenNow();
      if (success) {
        _pushTokenRetryAttempt = 0;
        _pushTokenRetryTimer?.cancel();
        _pushTokenRetryTimer = null;
      } else {
        _pendingPushTokenSync = true;
        _schedulePushTokenRetry();
      }
    } finally {
      _isSyncingPushToken = false;
      if (_pendingPushTokenSync && _pushTokenRetryTimer == null) {
        await _drainPushTokenSyncQueue();
      }
    }
  }

  Future<bool> _syncPushTokenNow() async {
    if (_isRealtimeEnabled) {
      _currentFcmToken ??= await _messaging?.getToken();
      final token = _currentFcmToken;
      if (token == null || token.trim().isEmpty) {
        debugPrint('FCM token sync skipped: token is empty');
        return false;
      }

      try {
        await _apiClient.post(
          '/notifications/push-token',
          body: {
            'token': token,
            'platform': defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android',
          },
        );
        await _storage.write(key: _registeredPushTokenKey, value: token);
        debugPrint(
          'FCM token synced to backend: token=${_describeToken(token)}',
        );
        return true;
      } catch (e) {
        debugPrint(
          'FCM token sync failed: token=${_describeToken(token)} error=$e',
        );
        return false;
      }
    }

    final token = await _tokenForUnregister();
    if (token == null || token.trim().isEmpty) {
      return true;
    }

    try {
      await _apiClient.post(
        '/notifications/push-token/unregister',
        body: {'token': token},
        requiresAuth: false,
      );
      await _storage.delete(key: _registeredPushTokenKey);
      debugPrint(
        'FCM token unregistered from backend: token=${_describeToken(token)}',
      );
      return true;
    } catch (e) {
      debugPrint(
        'FCM token unregister failed: token=${_describeToken(token)} error=$e',
      );
      return false;
    }
  }

  Future<String?> _tokenForUnregister() async {
    final token = _currentFcmToken;
    if (token != null && token.trim().isNotEmpty) {
      return token;
    }

    final stored = await _storage.read(key: _registeredPushTokenKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored;
    }
    return null;
  }

  void _schedulePushTokenRetry() {
    if (_pushTokenRetryTimer != null) {
      return;
    }

    _pushTokenRetryAttempt += 1;
    final delaySeconds = (_pushTokenRetryAttempt > 6
        ? 60
        : (1 << _pushTokenRetryAttempt));

    _pushTokenRetryTimer = Timer(Duration(seconds: delaySeconds), () async {
      _pushTokenRetryTimer = null;
      await _drainPushTokenSyncQueue();
    });
  }

  Future<void> _handleFcmForegroundMessage(RemoteMessage message) async {
    if (!_isRealtimeEnabled) {
      return;
    }

    final data = message.data;
    if (data.isEmpty) {
      return;
    }

    final mapped = _mapPushDataToNotificationItem(data, message: message);
    if (mapped == null) {
      return;
    }

    await _processNotificationEvent(mapped, preferFullscreen: true);
  }

  Map<String, dynamic>? _mapPushDataToNotificationItem(
    Map<String, dynamic> rawData, {
    RemoteMessage? message,
  }) {
    final data = rawData.map(
      (String key, dynamic value) => MapEntry(key.toString(), value),
    );
    final alertType = (data['alert_type'] ?? data['trigger_type'] ?? '')
        .toString()
        .toLowerCase();
    if (alertType.isEmpty) {
      return null;
    }

    final isRisk = _isRiskAlertType(alertType);
    final riskLevel = isRisk
        ? _resolveRiskLevel(
            data['risk_level']?.toString(),
            alertType: alertType,
          )
        : null;

    // SOS alerts require sosId; risk alerts use notification_id as identifier.
    final sosId = (data['sos_id'] ?? data['sos_event_id'] ?? data['event_id'])
        ?.toString();
    final notificationId = data['notification_id']?.toString();

    // For SOS: sosId is mandatory. For risk: notification_id suffices.
    final effectiveId = sosId?.isNotEmpty == true
        ? sosId!
        : (notificationId?.isNotEmpty == true ? notificationId! : null);
    if (effectiveId == null) {
      return null;
    }

    final createdAt =
        data['created_at']?.toString() ??
        DateTime.now().toUtc().toIso8601String();

    final String defaultTitle;
    final String defaultMessage;
    if (isRisk) {
      defaultTitle = riskLevel == 'critical'
          ? '🚨 Cảnh báo sức khỏe khẩn cấp'
          : '⚠️ Cảnh báo sức khỏe';
      defaultMessage = 'Phát hiện chỉ số sức khỏe bất thường. Nhấn để xem.';
    } else {
      defaultTitle = 'Cảnh báo SOS';
      defaultMessage = 'Có cảnh báo khẩn cấp mới';
    }

    final resolvedTitle =
        message?.notification?.title ??
        data['title']?.toString() ??
        defaultTitle;
    final resolvedMessage =
        message?.notification?.body ??
        data['body']?.toString() ??
        data['message']?.toString() ??
        defaultMessage;

    return {
      'id': (notificationId ?? '$alertType-$effectiveId').toString(),
      'alert_type': alertType,
      'severity': isRisk ? (riskLevel ?? 'medium') : 'critical',
      'title': resolvedTitle,
      'message': resolvedMessage,
      'data': {
        if (sosId != null && sosId.isNotEmpty) 'sos_id': sosId,
        if (sosId != null && sosId.isNotEmpty) 'sos_event_id': sosId,
        'trigger_type': data['trigger_type']?.toString(),
        if (isRisk) 'risk_level': riskLevel ?? 'medium',
        if (isRisk) 'notification_id': notificationId,
        if (isRisk) 'risk_score_id': data['risk_score_id'],
      },
      'created_at': createdAt,
      'is_read': false,
    };
  }

  Future<void> _handleRemoteMessageOpen(Map<String, dynamic> data) async {
    final target = parseRealtimeNotificationOpenTarget(data);
    if (target == null) {
      return;
    }

    if (target.type == 'risk') {
      final riskLevel = target.riskLevel ?? 'medium';
      if (riskLevel == 'critical') {
        await _presentCriticalRiskTarget(target);
      } else {
        await _navigateToNotificationsScreen();
      }
      return;
    }

    if (target.sosId == null || target.sosId!.isEmpty) {
      return;
    }
    await _navigateToSosDetail(target.sosId!);
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

  Future<void> _restorePendingCriticalAlertAfterAuth() async {
    if (!_isRealtimeEnabled) {
      return;
    }

    final target = _pendingCriticalAlertAfterAuth;
    if (target == null) {
      return;
    }

    _pendingCriticalAlertAfterAuth = null;
    await _presentCriticalRiskTarget(target);
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

  Future<void> _redirectCriticalAlertToAuth(
    RealtimeNotificationOpenTarget target,
  ) async {
    _pendingCriticalAlertAfterAuth = target;

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

  Future<void> _closeDialogAndRedirectCriticalAlertToAuth({
    required BuildContext dialogContext,
    required RealtimeNotificationOpenTarget target,
  }) async {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
    await _redirectCriticalAlertToAuth(target);
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

  Future<void> _connectWebSocket() async {
    if (!_isRealtimeEnabled || _isConnecting || kIsWeb) {
      return;
    }

    _isConnecting = true;
    try {
      final token = await _tokenStorageService.readAccessToken();
      if (token == null || token.isEmpty || !_isRealtimeEnabled) {
        return;
      }

      final wsUri = _buildNotificationWsUri(token);
      _wsChannel = WebSocketChannel.connect(wsUri);
      _wsSubscription = _wsChannel!.stream.listen(
        (dynamic event) {
          unawaited(_handleSocketEvent(event));
        },
        onError: (_) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  Uri _buildNotificationWsUri(String token) {
    final baseUri = Uri.parse(_apiClient.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final normalizedPath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    return baseUri.replace(
      scheme: wsScheme,
      path: '$normalizedPath/ws/notifications',
      queryParameters: {'token': token},
    );
  }

  Future<void> _handleSocketEvent(dynamic rawEvent) async {
    if (!_isRealtimeEnabled) {
      return;
    }

    try {
      final Map<String, dynamic> payload;
      if (rawEvent is String) {
        payload = Map<String, dynamic>.from(jsonDecode(rawEvent) as Map);
      } else if (rawEvent is Map) {
        payload = rawEvent.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      } else {
        return;
      }

      if (payload['type']?.toString() != 'notifications.update') {
        return;
      }

      final latestRaw = payload['latest_notification'];
      if (latestRaw is! Map) {
        return;
      }

      final latest = latestRaw.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      await _processNotificationEvent(latest, preferFullscreen: true);
    } catch (_) {
      // Ignore malformed payloads to keep realtime stream stable.
    }
  }

  Future<void> _processNotificationEvent(
    Map<String, dynamic> item, {
    required bool preferFullscreen,
  }) async {
    if (!_isEmergencyAlert(item)) {
      return;
    }

    final notificationId = item['id']?.toString();
    if (notificationId == null || notificationId.isEmpty) {
      return;
    }

    if (notificationId == _lastPresentedNotificationId) {
      return;
    }

    final createdAt = _parseCreatedAt(item);
    final lastSeenAt = await _readLastSeenAt();
    if (createdAt != null &&
        lastSeenAt != null &&
        !createdAt.isAfter(lastSeenAt)) {
      return;
    }

    final sosId = _extractSosId(item);
    if (sosId == null || sosId.isEmpty) {
      return;
    }

    final dedupeKey = _buildAlertDedupeKey(
      item,
      sosId: sosId,
      createdAt: createdAt,
    );
    if (_wasAlertPresentedRecently(dedupeKey)) {
      return;
    }

    if (preferFullscreen && _hasFullScreenIntentPermission != true) {
      await _ensureAndroidAlertPermissions(requestFullScreenIntent: true);
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

    if (preferFullscreen) {
      final shouldShowFullscreenRisk = !isRisk || riskLevel == 'critical';
      if (shouldShowFullscreenRisk) {
        await _showFullScreenAlert(item, sosId: sosId);
        if (isRisk) {
          await _presentCriticalRiskTarget(
            RealtimeNotificationOpenTarget(
              type: 'risk',
              notificationId: notificationId,
              alertType: alertType,
              riskLevel: riskLevel ?? 'critical',
              title: (item['title'] as String?) ?? 'Cảnh báo sức khỏe',
              message:
                  (item['message'] as String?) ??
                  'Phát hiện chỉ số sức khỏe bất thường.',
              riskScoreId: int.tryParse(
                _toMap(item['data'])['risk_score_id']?.toString() ?? '',
              ),
            ),
          );
        } else {
          await _navigateToEmergencyAlertScreen(
            sosId: sosId,
            title: (item['title'] as String?) ?? 'Canh bao khan cap',
            message:
                (item['message'] as String?) ??
                'Phat hien tinh huong khan cap. Nhan de xem chi tiet.',
          );
        }
      } else {
        await _showMissedAlert(item, sosId: sosId);
      }
    } else {
      await _showMissedAlert(item, sosId: sosId);
    }

    _rememberPresentedAlert(dedupeKey);

    _lastPresentedNotificationId = notificationId;
    await _storage.write(
      key: _scopedStorageKey(_lastPresentedIdKey),
      value: notificationId,
    );

    final fallbackSeenAt = DateTime.now().toUtc();
    await _saveLastSeenAt(createdAt ?? fallbackSeenAt);
  }

  /// Returns true for any risk_* alert types.
  bool _isRiskAlertType(String alertType) {
    return alertType.startsWith('risk_');
  }

  /// Returns true for any actionable alert (SOS, fall, or risk).
  bool _isEmergencyAlert(Map<String, dynamic> item) {
    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    return alertType == 'sos' ||
        alertType == 'manual' ||
        alertType.contains('sos') ||
        alertType == 'fall_detected' ||
        alertType == 'fall_detection' ||
        _isRiskAlertType(alertType);
  }

  String _resolveRiskLevel(String? rawLevel, {required String alertType}) {
    return resolveRealtimeRiskLevel(rawLevel, alertType: alertType);
  }

  String _buildAlertDedupeKey(
    Map<String, dynamic> item, {
    required String sosId,
    required DateTime? createdAt,
  }) {
    final notificationId = item['id']?.toString();
    if (notificationId != null && notificationId.isNotEmpty) {
      return 'id:$notificationId';
    }

    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? 'unknown';
    final createdPart = createdAt?.toIso8601String() ?? 'unknown-time';
    return 'fallback:$alertType:$sosId:$createdPart';
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

  DateTime? _parseCreatedAt(Map<String, dynamic> item) {
    final raw = item['created_at'];
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  /// Extract SOS ID or, for risk alerts, fall back to notification_id / item id.
  String? _extractSosId(Map<String, dynamic> item) {
    final data = _toMap(item['data']);
    final candidates = <Object?>[
      item['sos_id'],
      item['sos_event_id'],
      data['sos_id'],
      data['sos_event_id'],
      data['sosId'],
      data['sosEventId'],
      data['event_id'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final value = candidate.toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }

    // Risk alerts may not have sosId — use notification_id or item id.
    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    if (_isRiskAlertType(alertType)) {
      final fallbackId = (data['notification_id'] ?? item['id'])?.toString();
      if (fallbackId != null && fallbackId.isNotEmpty) {
        return fallbackId;
      }
    }
    return null;
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

  Future<void> _dispatchMissedAlertsOnReLogin() async {
    if (!_isRealtimeEnabled) {
      return;
    }

    try {
      final result = await _apiClient.get(
        '/notifications',
        queryParams: {'limit': 50, 'offset': 0, 'unread_only': false},
      );

      final rawList = (result['notifications'] as List?) ?? const [];
      final allItems = rawList
          .whereType<Map>()
          .map(
            (Map item) => item.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          )
          .toList();

      final now = DateTime.now().toUtc();
      final lastSeenCutoff = await _readLastSeenAt();

      final missed = allItems.where((item) {
        if (!_isEmergencyAlert(item)) {
          return false;
        }
        final createdAt = _parseCreatedAt(item);
        if (createdAt == null) {
          return false;
        }

        if (lastSeenCutoff != null) {
          return createdAt.isAfter(lastSeenCutoff);
        }

        // No local cursor yet: only catch up recent alerts to avoid ringing
        // historical data on first launch/install.
        return now.difference(createdAt) <= _reLoginRingingWindow;
      }).toList();

      if (missed.isEmpty) {
        if (lastSeenCutoff == null && allItems.isNotEmpty) {
          final newest = allItems
              .map(_parseCreatedAt)
              .whereType<DateTime>()
              .fold<DateTime?>(null, (acc, dt) {
                if (acc == null) {
                  return dt;
                }
                return dt.isAfter(acc) ? dt : acc;
              });
          if (newest != null) {
            await _saveLastSeenAt(newest);
          }
        }
        return;
      }

      missed.sort((a, b) {
        final aTime = _parseCreatedAt(a);
        final bTime = _parseCreatedAt(b);
        if (aTime == null || bTime == null) {
          return 0;
        }
        return aTime.compareTo(bTime);
      });

      final toNotify = missed.length > 5
          ? missed.sublist(missed.length - 5)
          : missed;

      Map<String, dynamic>? ringCandidate;
      String? ringCandidateId;
      for (final item in toNotify) {
        final createdAt = _parseCreatedAt(item);
        if (createdAt == null) {
          continue;
        }
        final isWithinWindow =
            now.difference(createdAt) <= _reLoginRingingWindow;
        if (!isWithinWindow) {
          continue;
        }
        ringCandidate = item;
        ringCandidateId = item['id']?.toString();
      }

      // Guarantee at least one promoted alert during catch-up so users who
      // just logged back in can still notice a recent emergency event.
      ringCandidate ??= toNotify.isNotEmpty ? toNotify.last : null;
      ringCandidateId ??= ringCandidate?['id']?.toString();

      for (final item in toNotify) {
        final shouldRing = item['id']?.toString() == ringCandidateId;
        await _processNotificationEvent(item, preferFullscreen: shouldRing);
      }
    } catch (_) {
      // Skip catch-up notifications on transient failures.
    }
  }

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return;
      }

      final map = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      await _handleRemoteMessageOpen(map);
    } catch (_) {
      // Ignore tap payload errors.
    }
  }

  Future<DateTime?> _readLastSeenAt() async {
    final raw = await _storage.read(key: _scopedStorageKey(_lastSeenAtKey));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _saveLastSeenAt(DateTime time) async {
    await _storage.write(
      key: _scopedStorageKey(_lastSeenAtKey),
      value: time.toUtc().toIso8601String(),
    );
  }

  Future<void> _stopRealtime() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pushTokenRetryTimer?.cancel();
    _pushTokenRetryTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _scheduleReconnect() {
    if (!_isRealtimeEnabled || _reconnectTimer != null) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 4), () async {
      _reconnectTimer = null;
      await _connectWebSocket();
    });
  }

  Future<void> dispose() async {
    _stopOverlayVibrationPulse();
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    _pushTokenRetryTimer?.cancel();
    _pushTokenRetryTimer = null;
    await _fcmForegroundSubscription?.cancel();
    _fcmForegroundSubscription = null;
    await _fcmOpenedAppSubscription?.cancel();
    _fcmOpenedAppSubscription = null;
    await _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;
  }
}
