import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_client.dart';
import '../../auth/services/token_storage_service.dart';
import '../models/notification_open_target.dart';
import 'notification_event_mapper.dart';
import 'notification_open_router.dart';

const String _androidCriticalAlertChannel =
    'healthguard/emergency/critical_alert';
const String _androidOnCriticalAlertLaunchMethod = 'onCriticalAlertLaunch';
const String _androidConsumePendingCriticalAlertLaunchMethod =
    'consumePendingCriticalAlertLaunch';
const String _androidDefaultNotificationIcon = '@mipmap/ic_launcher';
// Channel IDs are bumped to ``_v2`` so we can ship channels with
// explicit sound + vibration settings.  Android 8+ locks notification
// channel settings on the first ``createNotificationChannel`` call
// (per-notification overrides are ignored after that), so we cannot
// retroactively patch the original ``sos_fullscreen_alerts`` /
// ``risk_critical_alerts`` channels that shipped without sound +
// vibrationPattern set.  Bumping to a new id forces Android to honour
// our explicit settings; the legacy channel is deleted on init.
const String _backgroundRiskCriticalChannelId = 'risk_critical_alerts_v3';
const String _backgroundRiskCriticalChannelName = 'Risk Critical Alerts';
const String _backgroundSosChannelId = 'sos_fullscreen_alerts_v3';
const String _backgroundSosChannelName = 'SOS Fullscreen Alerts';
const String _backgroundFallChannelId = 'fall_alerts_v1';
const String _backgroundFallChannelName = 'Fall Alerts';

// Legacy IDs kept for one-shot deletion on init so old installs don't
// leave a silent channel lingering in Android Settings.
const String _legacyBackgroundRiskCriticalChannelId = 'risk_critical_alerts';
const String _legacyBackgroundRiskCriticalChannelIdV2 = 'risk_critical_alerts_v2';
const String _legacyBackgroundSosChannelId = 'sos_fullscreen_alerts';
const String _legacyBackgroundSosChannelIdV2 = 'sos_fullscreen_alerts_v2';

/// Per-type notification sounds — each maps to a file in android/app/src/main/res/raw/.
const _emergencyAlertSound =
    RawResourceAndroidNotificationSound('emergency_alert');
const _healthEmergencySound =
    RawResourceAndroidNotificationSound('health_emergency');
const _fallAlertSound =
    RawResourceAndroidNotificationSound('fall_alert');

final FlutterLocalNotificationsPlugin _backgroundNotifications =
    FlutterLocalNotificationsPlugin();
bool _backgroundNotificationsInitialized = false;

abstract interface class NotificationEmergencyAdapter {
  Future<void> openNotifications();
  Future<void> openSosDetail(String sosId);
  Future<void> presentCriticalRiskTarget(NotificationOpenTarget target);
  Future<void> presentFullscreenAlert(
    Map<String, dynamic> item, {
    required String subjectId,
  });
  Future<void> presentMissedAlert(
    Map<String, dynamic> item, {
    required String subjectId,
  });
  Future<void> redirectCriticalAlertToAuth(NotificationOpenTarget target);

  /// Module FA-2: open the patient-facing [FallAlertScreen] in response
  /// to a ``fall_alert`` push.  Distinct from [openSosDetail] because
  /// the fall flow has its own 30s countdown + dismiss + survey UX
  /// that must not be hijacked by the SOS state-machine.
  Future<void> presentFallAlert({
    required int fallEventId,
    String? fallEventUuid,
    double confidence = 0.0,
  });
}

int _deriveCriticalRiskNotificationId(String notificationId) {
  return 300000 + (notificationId.hashCode.abs() % 600000);
}

int _deriveSosNotificationId(String sosId) {
  return 400000 + (sosId.hashCode.abs() % 500000);
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
  // One-shot cleanup: drop legacy v1 + v2 channels so Android Settings
  // doesn't keep a stale silent entry. Safe no-op if they don't exist.
  await androidPlugin?.deleteNotificationChannel(
    _legacyBackgroundRiskCriticalChannelId,
  );
  await androidPlugin?.deleteNotificationChannel(
    _legacyBackgroundRiskCriticalChannelIdV2,
  );
  await androidPlugin?.deleteNotificationChannel(
    _legacyBackgroundSosChannelId,
  );
  await androidPlugin?.deleteNotificationChannel(
    _legacyBackgroundSosChannelIdV2,
  );

  // Both channels register with the SAME loud vibration pattern + sound
  // as the per-notification ``AndroidNotificationDetails`` payload below
  // — channel settings win on Android 8+, so this is the only place
  // these values actually take effect.
  // NOTE: Android 8+ locks channel settings on first creation.
  // If the device previously had a v1 channel without sound, we
  // deleted it above and re-create here with explicit sound+vibration.
  // If sound is still silent after the first run, the user must
  // UNINSTALL + REINSTALL the app to clear all cached channel state.
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      _backgroundRiskCriticalChannelId,
      _backgroundRiskCriticalChannelName,
      description: 'Cảnh báo chỉ số sức khỏe nguy hiểm',
      importance: Importance.max,
      playSound: true,
      sound: _healthEmergencySound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
        const <int>[0, 900, 400, 900, 400, 1400],
      ),
    ),
  );
  debugPrint(
    'Background channel registered: $_backgroundRiskCriticalChannelId '
    '(sound=health_emergency vibration=true)',
  );
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      _backgroundSosChannelId,
      _backgroundSosChannelName,
      description: 'Cảnh báo SOS khẩn cấp toàn màn hình',
      importance: Importance.max,
      playSound: true,
      sound: _emergencyAlertSound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
        const <int>[0, 900, 400, 900, 400, 1400],
      ),
    ),
  );
  debugPrint(
    'Background channel registered: $_backgroundSosChannelId '
    '(sound=emergency_alert vibration=true)',
  );
  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      _backgroundFallChannelId,
      _backgroundFallChannelName,
      description: 'Cảnh báo phát hiện té ngã',
      importance: Importance.max,
      playSound: true,
      sound: _fallAlertSound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(
        const <int>[0, 900, 400, 900, 400, 1400],
      ),
    ),
  );
  debugPrint(
    'Background channel registered: $_backgroundFallChannelId '
    '(sound=fall_alert vibration=true)',
  );

  _backgroundNotificationsInitialized = true;
}

Future<void> _showBackgroundCriticalRiskNotification(
  RemoteMessage message,
) async {
  final payload = buildNotificationAndroidCriticalRiskLaunchPayload(
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
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      sound: _healthEmergencySound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 900, 400, 900, 400, 1400]),
      visibility: NotificationVisibility.public,
      autoCancel: true,
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

/// P1 #5: full-screen takeover for SOS / fall_detected emergencies in
/// background / cold-start. Mirrors [_showBackgroundCriticalRiskNotification].
Future<void> _showBackgroundSosNotification(RemoteMessage message) async {
  final payload = buildNotificationAndroidSosLaunchPayload(
    message.data,
    fallbackTitle: message.notification?.title,
    fallbackBody: message.notification?.body,
  );
  if (payload == null) {
    return;
  }

  await _initializeBackgroundNotifications();

  final sosId = payload['sosId']?.toString() ?? '';
  if (sosId.isEmpty) {
    return;
  }

  final alertType = (message.data['alert_type'] as String? ?? '').toLowerCase();
  final isFall = isFallAlertType(alertType);
  final channelId =
      isFall ? _backgroundFallChannelId : _backgroundSosChannelId;
  final channelName =
      isFall ? _backgroundFallChannelName : _backgroundSosChannelName;
  final channelDesc = isFall
      ? 'Cảnh báo phát hiện té ngã'
      : 'Cảnh báo SOS khẩn cấp toàn màn hình';
  final sound = isFall ? _fallAlertSound : _emergencyAlertSound;

  final notificationId = _deriveSosNotificationId(sosId);
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      sound: sound,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 900, 400, 900, 400, 1400]),
      visibility: NotificationVisibility.public,
      autoCancel: true,
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
Future<void> notificationFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  // Try the critical-risk takeover first; if not applicable, try the
  // SOS / fall takeover. Both helpers are idempotent + payload-gated, so it
  // is safe to call them sequentially.
  await _showBackgroundCriticalRiskNotification(message);
  await _showBackgroundSosNotification(message);
}

class NotificationRuntimeService {
  NotificationRuntimeService({
    required NotificationEmergencyAdapter emergencyAdapter,
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    FlutterSecureStorage? storage,
    FlutterLocalNotificationsPlugin? notifications,
    MethodChannel? androidCriticalAlertBridge,
    Duration reLoginRingingWindow = const Duration(hours: 1),
  }) : _emergencyAdapter = emergencyAdapter,
       _apiClient = apiClient ?? ApiClient(),
       _tokenStorageService = tokenStorageService ?? TokenStorageService(),
       _storage = storage ?? const FlutterSecureStorage(),
       _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
       _androidCriticalAlertBridge =
           androidCriticalAlertBridge ??
           const MethodChannel(_androidCriticalAlertChannel),
       _reLoginRingingWindow = reLoginRingingWindow;

  // Channel IDs are bumped to ``_v2`` so we can register them with
  // explicit sound + vibration patterns; the legacy ids are deleted in
  // ``_ensureNotificationChannels`` to avoid lingering silent entries
  // in Android Settings.  See top-level comment in this file.
  static const String _fullScreenChannelId = 'sos_fullscreen_alerts_v3';
  static const String _fullScreenChannelName = 'SOS Fullscreen Alerts';
  static const String _fallChannelId = 'fall_alerts_v1';
  static const String _fallChannelName = 'Fall Alerts';
  static const String _legacyFullScreenChannelId = 'sos_fullscreen_alerts';
  static const String _legacyFullScreenChannelIdV2 = 'sos_fullscreen_alerts_v2';
  static const String _missedChannelId = 'sos_missed_alerts';
  static const String _missedChannelName = 'SOS Missed Alerts';
  static const String _riskChannelId = 'risk_alerts';
  static const String _riskChannelName = 'Risk Alerts';
  static const String _riskCriticalChannelId = 'risk_critical_alerts_v3';
  static const String _riskCriticalChannelName = 'Risk Critical Alerts';
  static const String _legacyRiskCriticalChannelId = 'risk_critical_alerts';
  static const String _legacyRiskCriticalChannelIdV2 = 'risk_critical_alerts_v2';

  static const String _lastSeenAtKey = 'sos_last_seen_alert_created_at';
  static const String _lastPresentedIdKey =
      'sos_last_presented_notification_id';
  static const String _registeredPushTokenKey = 'sos_registered_push_token';

  final NotificationEmergencyAdapter _emergencyAdapter;
  final ApiClient _apiClient;
  final TokenStorageService _tokenStorageService;
  final FlutterSecureStorage _storage;
  final FlutterLocalNotificationsPlugin _notifications;
  final MethodChannel _androidCriticalAlertBridge;
  final Duration _reLoginRingingWindow;

  FirebaseMessaging? _messaging;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;
  StreamSubscription<RemoteMessage>? _fcmOpenedAppSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  Timer? _reconnectTimer;
  Timer? _pushTokenRetryTimer;

  bool _isInitialized = false;
  bool _isFcmInitialized = false;
  bool _isRealtimeEnabled = false;
  bool _hasAppliedAuthState = false;
  bool _isConnecting = false;
  bool _isSyncingPushToken = false;
  bool _pendingPushTokenSync = false;
  bool _androidCriticalAlertBridgeInitialized = false;
  int _pushTokenRetryAttempt = 0;
  String? _lastPresentedNotificationId;
  String? _currentFcmToken;
  bool? _hasFullScreenIntentPermission;
  bool? _deferredAuthState;
  VoidCallback? _onFullScreenIntentPermissionDenied;

  /// `true` if USE_FULL_SCREEN_INTENT is granted (Android 14+).
  /// `null` means the check hasn't run yet or is not applicable (Android < 14).
  /// `false` means explicitly denied — full-screen takeover will not work.
  bool? get fullScreenIntentPermission => _hasFullScreenIntentPermission;

  /// Register a callback invoked once when USE_FULL_SCREEN_INTENT is found
  /// to be denied.  Useful for showing an in-app warning banner.
  void setOnFullScreenIntentPermissionDenied(VoidCallback callback) {
    _onFullScreenIntentPermissionDenied = callback;
  }

  /// Re-trigger the USE_FULL_SCREEN_INTENT permission dialog (Android 14+).
  /// On Android ≤ 13 this is a no-op; the manifest declaration is sufficient.
  Future<void> openFullScreenIntentSettings() async {
    if (kIsWeb) return;
    await _ensureAndroidAlertPermissions(requestFullScreenIntent: true);
  }

  String _activeStorageScope = 'signed_out';
  final Map<String, DateTime> _recentAlertPresentation = {};
  NotificationOpenTarget? _pendingCriticalAlertAfterAuth;
  String? _pendingNotificationTapPayload;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      _androidDefaultNotificationIcon,
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

    // Drop legacy v1 + v2 channels so Settings doesn't keep stale silent entries.
    // Safe no-op if they don't exist.
    await androidPlugin?.deleteNotificationChannel(_legacyFullScreenChannelId);
    await androidPlugin?.deleteNotificationChannel(_legacyFullScreenChannelIdV2);
    await androidPlugin?.deleteNotificationChannel(_legacyRiskCriticalChannelId);
    await androidPlugin?.deleteNotificationChannel(_legacyRiskCriticalChannelIdV2);

    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _fullScreenChannelId,
        _fullScreenChannelName,
        description: 'Cảnh báo SOS khẩn cấp toàn màn hình',
        importance: Importance.max,
        playSound: true,
        sound: _emergencyAlertSound,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(
          const <int>[0, 900, 400, 900, 400, 1400],
        ),
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _fallChannelId,
        _fallChannelName,
        description: 'Cảnh báo phát hiện té ngã',
        importance: Importance.max,
        playSound: true,
        sound: _fallAlertSound,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(
          const <int>[0, 900, 400, 900, 400, 1400],
        ),
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
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _riskChannelId,
        _riskChannelName,
        description: 'Cảnh báo chỉ số sức khỏe bất thường',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _riskCriticalChannelId,
        _riskCriticalChannelName,
        description: 'Cảnh báo chỉ số sức khỏe nguy hiểm',
        importance: Importance.max,
        playSound: true,
        sound: _healthEmergencySound,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(
          const <int>[0, 900, 400, 900, 400, 1400],
        ),
      ),
    );

    _lastPresentedNotificationId = null;

    // Cold-start: check if the app was launched by tapping a local notification.
    // flutter_local_notifications fires onDidReceiveNotificationResponse for
    // background-tap case, but not always for the truly-killed state.
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final coldPayload = launchDetails?.notificationResponse?.payload;
      if (coldPayload != null && coldPayload.trim().isNotEmpty) {
        _pendingNotificationTapPayload = coldPayload;
        debugPrint('Cold-start notification tap detected — payload stored for replay');
      }
    }

    await _initializeAndroidCriticalAlertBridge();
    await _initializeFcm();
    _isInitialized = true;

    // Replay any notification tap that arrived before init finished.
    // (onAuthStateChanged will also call this once auth completes.)
    if (_isRealtimeEnabled) {
      await _restorePendingNotificationTap();
    }

    final deferredAuthState = _deferredAuthState;
    _deferredAuthState = null;
    if (deferredAuthState != null) {
      await onAuthStateChanged(isAuthenticated: deferredAuthState);
    }
  }

  Future<void> onAuthStateChanged({required bool isAuthenticated}) async {
    if (!_isInitialized) {
      _deferredAuthState = isAuthenticated;
      return;
    }

    _deferredAuthState = null;

    final isInitialAuthSync = !_hasAppliedAuthState;
    if (!isInitialAuthSync && isAuthenticated == _isRealtimeEnabled) {
      return;
    }

    _hasAppliedAuthState = true;
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
    await _restorePendingNotificationTap();
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
  Future<void> redirectCriticalAlertToAuthForTest(NotificationOpenTarget target) {
    return redirectCriticalAlertToAuth(target);
  }

  @visibleForTesting
  Future<void> restorePendingCriticalAlertAfterAuthForTest() {
    return _restorePendingCriticalAlertAfterAuth();
  }

  @visibleForTesting
  NotificationOpenTarget? get pendingCriticalAlertForTest =>
      _pendingCriticalAlertAfterAuth;

  @visibleForTesting
  void setRealtimeEnabledForTest(bool value) {
    _isRealtimeEnabled = value;
  }

  Future<void> redirectCriticalAlertToAuth(NotificationOpenTarget target) {
    return _redirectCriticalAlertToAuth(target);
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

      _fcmForegroundSubscription = FirebaseMessaging.onMessage.listen((message) {
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
    final riskTarget =
        parseNotificationAndroidCriticalRiskLaunchPayload(rawPayload);
    if (riskTarget != null) {
      await _presentCriticalRiskTarget(riskTarget);
      return;
    }

    final target = parseNotificationOpenTarget(_decodePayloadMap(rawPayload));
    if (target == null) return;

    final alertType = target.alertType?.trim().toLowerCase() ?? '';
    if (alertType == 'fall_detected' || alertType == 'fall_detection') {
      final fallEventId = int.tryParse(target.sosId ?? '');
      if (fallEventId == null) return;
      await _emergencyAdapter.presentFallAlert(fallEventId: fallEventId);
      return;
    }

    final sosId = target.sosId?.trim();
    if (sosId != null && sosId.isNotEmpty) {
      await _emergencyAdapter.openSosDetail(sosId);
    }
  }

  static Map<String, dynamic> _decodePayloadMap(dynamic rawPayload) {
    if (rawPayload is Map<String, dynamic>) return rawPayload;
    if (rawPayload is Map) {
      return rawPayload.map(
        (dynamic k, dynamic v) => MapEntry(k.toString(), v),
      );
    }
    if (rawPayload is String) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          return decoded.map(
            (dynamic k, dynamic v) => MapEntry(k.toString(), v),
          );
        }
      } catch (_) {}
    }
    return {};
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
        'Notification runtime permission: ${notificationsGranted ?? false}',
      );
    } catch (e) {
      debugPrint('Notification runtime permission request skipped: $e');
    }

    if (!requestFullScreenIntent) {
      return;
    }

    try {
      final hasFullScreenPermission = await androidPlugin
          .requestFullScreenIntentPermission();
      _hasFullScreenIntentPermission = hasFullScreenPermission;
      if (hasFullScreenPermission == false) {
        debugPrint(
          '⚠️ USE_FULL_SCREEN_INTENT permission DENIED — '
          'fullscreen alerts will show as HUD banners only. '
          'User must grant via Settings → Apps → HealthGuard → '
          'Special app access → Display over other apps / Alarms.',
        );
        _onFullScreenIntentPermissionDenied?.call();
      } else {
        debugPrint(
          'Notification runtime full-screen permission: ${hasFullScreenPermission ?? 'n/a (Android < 14)'}',
        );
      }
    } catch (e) {
      debugPrint(
        'Notification runtime full-screen permission request skipped: $e',
      );
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
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
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

    final event = mapNotificationEventFromPushData(data, message: message);
    if (event == null) {
      return;
    }

    await _processNotificationEvent(event.toItemMap(), preferFullscreen: true);
  }

  Future<void> _handleRemoteMessageOpen(Map<String, dynamic> data) async {
    final target = parseNotificationOpenTarget(data);
    if (target == null) {
      return;
    }

    if (target.type == 'risk') {
      final riskLevel = target.riskLevel ?? 'medium';
      if (riskLevel == 'critical') {
        await _presentCriticalRiskTarget(target);
      } else {
        await _emergencyAdapter.openNotifications();
      }
      return;
    }

    // Module FA-2: fall pushes share the SOS subjectId slot but the
    // tap target is FallAlertScreen, not SosDetail.  Detect via the
    // alertType marker we set in parseNotificationOpenTarget.
    final alertType = target.alertType?.trim().toLowerCase() ?? '';
    if (alertType == 'fall_detected' || alertType == 'fall_detection') {
      final fallEventIdRaw =
          (data['fall_event_id'] ?? data['fallEventId'] ?? target.sosId)
              ?.toString();
      final fallEventId = int.tryParse(fallEventIdRaw ?? '');
      if (fallEventId == null) {
        return;
      }
      final fallEventUuid =
          (data['fall_event_uuid'] ?? data['fallEventUuid'])?.toString();
      final confidence = double.tryParse(
        (data['confidence'] ?? '').toString(),
      ) ?? 0.0;
      await _emergencyAdapter.presentFallAlert(
        fallEventId: fallEventId,
        fallEventUuid: fallEventUuid,
        confidence: confidence,
      );
      return;
    }

    final sosId = target.sosId?.trim();
    if (sosId == null || sosId.isEmpty) {
      return;
    }
    await _emergencyAdapter.openSosDetail(sosId);
  }

  String _buildCriticalRiskLaunchDedupeKey(String notificationId) {
    return 'critical-launch:$notificationId';
  }

  Future<void> _presentCriticalRiskTarget(NotificationOpenTarget target) async {
    final notificationId = target.notificationId?.trim();
    if (notificationId == null || notificationId.isEmpty) {
      return;
    }

    final dedupeKey = _buildCriticalRiskLaunchDedupeKey(notificationId);
    if (_wasAlertPresentedRecently(dedupeKey)) {
      return;
    }

    _rememberPresentedAlert(dedupeKey);
    await _emergencyAdapter.presentCriticalRiskTarget(target);
  }

  Future<void> _redirectCriticalAlertToAuth(NotificationOpenTarget target) async {
    _pendingCriticalAlertAfterAuth = target;
    await _emergencyAdapter.redirectCriticalAlertToAuth(target);
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

    final subjectId = extractNotificationSubjectId(item);
    if (subjectId == null || subjectId.isEmpty) {
      return;
    }

    final dedupeKey = _buildAlertDedupeKey(
      item,
      subjectId: subjectId,
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
    final isRisk = isRiskAlertType(alertType);
    final riskLevel = isRisk
        ? resolveNotificationRiskLevel(
            _toMap(item['data'])['risk_level']?.toString(),
            alertType: alertType,
          )
        : null;

    if (preferFullscreen) {
      final shouldShowFullscreenRisk = !isRisk || riskLevel == 'critical';
      if (shouldShowFullscreenRisk) {
        await _emergencyAdapter.presentFullscreenAlert(
          item,
          subjectId: subjectId,
        );
        if (isRisk) {
          await _presentCriticalRiskTarget(
            NotificationOpenTarget(
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
        }
      } else {
        await _emergencyAdapter.presentMissedAlert(item, subjectId: subjectId);
      }
    } else {
      await _emergencyAdapter.presentMissedAlert(item, subjectId: subjectId);
    }

    _rememberPresentedAlert(dedupeKey);

    _lastPresentedNotificationId = notificationId;
    await _storage.write(
      key: _scopedStorageKey(_lastPresentedIdKey),
      value: notificationId,
    );

    await _saveLastSeenAt(createdAt ?? DateTime.now().toUtc());
  }

  bool _isEmergencyAlert(Map<String, dynamic> item) {
    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    return isActionableNotificationType(alertType);
  }

  String _buildAlertDedupeKey(
    Map<String, dynamic> item, {
    required String subjectId,
    required DateTime? createdAt,
  }) {
    final notificationId = item['id']?.toString();
    if (notificationId != null && notificationId.isNotEmpty) {
      return 'id:$notificationId';
    }

    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? 'unknown';
    final createdPart = createdAt?.toIso8601String() ?? 'unknown-time';
    return 'fallback:$alertType:$subjectId:$createdPart';
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

    // Guard: if initialisation hasn't finished yet (cold-start race) or the
    // user is not authenticated yet, stash the payload and replay it once
    // both conditions are satisfied (see _restorePendingNotificationTap).
    if (!_isInitialized || !_isRealtimeEnabled) {
      _pendingNotificationTapPayload = payload;
      debugPrint('Notification tap deferred — not ready yet (init=$_isInitialized realtime=$_isRealtimeEnabled)');
      return;
    }

    await _dispatchNotificationTapPayload(payload);
  }

  Future<void> _dispatchNotificationTapPayload(String payload) async {
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

  Future<void> _restorePendingNotificationTap() async {
    if (!_isRealtimeEnabled) return;
    final payload = _pendingNotificationTapPayload;
    if (payload == null || payload.trim().isEmpty) return;
    _pendingNotificationTapPayload = null;
    debugPrint('Replaying deferred notification tap after auth/init');
    await _dispatchNotificationTapPayload(payload);
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pushTokenRetryTimer?.cancel();
    _pushTokenRetryTimer = null;
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    await _fcmForegroundSubscription?.cancel();
    _fcmForegroundSubscription = null;
    await _fcmOpenedAppSubscription?.cancel();
    _fcmOpenedAppSubscription = null;
    await _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = null;
  }
}
