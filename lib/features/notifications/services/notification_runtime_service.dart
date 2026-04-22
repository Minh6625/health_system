import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
const String _backgroundRiskCriticalChannelId = 'risk_critical_alerts';
const String _backgroundRiskCriticalChannelName = 'Risk Critical Alerts';

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
}

abstract interface class NotificationRuntimeNavigatorOwner {
  void bindNotificationRuntimeNavigatorKey(
    GlobalKey<NavigatorState> navigatorKey,
  );
}

abstract interface class NotificationRuntimeNotificationsOwner {
  FlutterLocalNotificationsPlugin get notificationRuntimeNotifications;
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
Future<void> notificationFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  await _showBackgroundCriticalRiskNotification(message);
}

class NotificationRuntimeService {
  NotificationRuntimeService._internal({
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

  factory NotificationRuntimeService.instance({
    required NotificationEmergencyAdapter emergencyAdapter,
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    FlutterSecureStorage? storage,
    FlutterLocalNotificationsPlugin? notifications,
    MethodChannel? androidCriticalAlertBridge,
    Duration reLoginRingingWindow = const Duration(hours: 1),
  }) {
    return NotificationRuntimeService._internal(
      emergencyAdapter: emergencyAdapter,
      apiClient: apiClient,
      tokenStorageService: tokenStorageService,
      storage: storage,
      notifications:
          notifications ??
          (emergencyAdapter is NotificationRuntimeNotificationsOwner
              ? (emergencyAdapter as NotificationRuntimeNotificationsOwner)
                    .notificationRuntimeNotifications
              : null),
      androidCriticalAlertBridge: androidCriticalAlertBridge,
      reLoginRingingWindow: reLoginRingingWindow,
    );
  }

  @visibleForTesting
  factory NotificationRuntimeService.test({
    required NotificationEmergencyAdapter emergencyAdapter,
    ApiClient? apiClient,
    TokenStorageService? tokenStorageService,
    FlutterSecureStorage? storage,
    FlutterLocalNotificationsPlugin? notifications,
    MethodChannel? androidCriticalAlertBridge,
    Duration reLoginRingingWindow = const Duration(hours: 1),
  }) {
    return NotificationRuntimeService._internal(
      emergencyAdapter: emergencyAdapter,
      apiClient: apiClient,
      tokenStorageService: tokenStorageService,
      storage: storage,
      notifications:
          notifications ??
          (emergencyAdapter is NotificationRuntimeNotificationsOwner
              ? (emergencyAdapter as NotificationRuntimeNotificationsOwner)
                    .notificationRuntimeNotifications
              : null),
      androidCriticalAlertBridge: androidCriticalAlertBridge,
      reLoginRingingWindow: reLoginRingingWindow,
    );
  }

  static const String _fullScreenChannelId = 'sos_fullscreen_alerts';
  static const String _fullScreenChannelName = 'SOS Fullscreen Alerts';
  static const String _missedChannelId = 'sos_missed_alerts';
  static const String _missedChannelName = 'SOS Missed Alerts';
  static const String _riskChannelId = 'risk_alerts';
  static const String _riskChannelName = 'Risk Alerts';
  static const String _riskCriticalChannelId = 'risk_critical_alerts';
  static const String _riskCriticalChannelName = 'Risk Critical Alerts';

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
  NotificationOpenTarget? _pendingCriticalAlertAfterAuth;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_emergencyAdapter is NotificationRuntimeNavigatorOwner) {
      (_emergencyAdapter as NotificationRuntimeNavigatorOwner)
          .bindNotificationRuntimeNavigatorKey(navigatorKey);
    }

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
  Future<void> redirectCriticalAlertToAuthForTest(NotificationOpenTarget target) {
    return _redirectCriticalAlertToAuth(target);
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
    final target = parseNotificationAndroidCriticalRiskLaunchPayload(rawPayload);
    if (target == null) {
      return;
    }

    await _presentCriticalRiskTarget(target);
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
      debugPrint(
        'Notification runtime full-screen permission: ${hasFullScreenPermission ?? false}',
      );
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
