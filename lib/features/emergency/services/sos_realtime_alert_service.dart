import 'dart:async';
import 'dart:convert';

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
import '../../family/models/family_profile_snapshot.dart';
import '../../family/widgets/family_sos_full_screen_overlay.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep isolate alive and let system notification deliver when app is background/terminated.
  await Firebase.initializeApp();
}

class SOSRealtimeAlertService {
  SOSRealtimeAlertService._();

  static final SOSRealtimeAlertService instance = SOSRealtimeAlertService._();

  static const String _fullScreenChannelId = 'sos_fullscreen_alerts';
  static const String _fullScreenChannelName = 'SOS Fullscreen Alerts';
  static const String _missedChannelId = 'sos_missed_alerts';
  static const String _missedChannelName = 'SOS Missed Alerts';

  static const String _lastSeenAtKey = 'sos_last_seen_alert_created_at';
  static const String _lastPresentedIdKey =
      'sos_last_presented_notification_id';
  static const String _registeredPushTokenKey = 'sos_registered_push_token';
  static const Duration _reLoginRingingWindow = Duration(hours: 1);
  static const Duration _overlayVibrationInterval = Duration(milliseconds: 420);

  final ApiClient _apiClient = ApiClient();
  final TokenStorageService _tokenStorageService = TokenStorageService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

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

    await _ensureAndroidAlertPermissions(requestFullScreenIntent: false);

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

    _lastPresentedNotificationId = null;

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

      _fcmTokenRefreshSubscription = _messaging!.onTokenRefresh.listen((token) {
        _currentFcmToken = token;
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
        unawaited(_openSosDetailFromRemoteData(message.data));
      });

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_openSosDetailFromRemoteData(initialMessage.data));
      }

      _isFcmInitialized = true;
    } catch (e) {
      debugPrint('FCM init skipped: $e');
    }
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
        return true;
      } catch (_) {
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
      return true;
    } catch (_) {
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

    final sosId = (data['sos_id'] ?? data['sos_event_id'] ?? data['event_id'])
        ?.toString();
    if (sosId == null || sosId.isEmpty) {
      return null;
    }

    final createdAt =
        data['created_at']?.toString() ??
        DateTime.now().toUtc().toIso8601String();
    final resolvedTitle =
        message?.notification?.title ??
        data['title']?.toString() ??
        'Cảnh báo SOS';
    final resolvedMessage =
        message?.notification?.body ??
        data['body']?.toString() ??
        data['message']?.toString() ??
        'Có cảnh báo khẩn cấp mới';

    return {
      'id': (data['notification_id'] ?? '$alertType-$sosId').toString(),
      'alert_type': alertType,
      'severity': 'critical',
      'title': resolvedTitle,
      'message': resolvedMessage,
      'data': {
        'sos_id': sosId,
        'sos_event_id': sosId,
        'trigger_type': data['trigger_type']?.toString(),
      },
      'created_at': createdAt,
      'is_read': false,
    };
  }

  Future<void> _openSosDetailFromRemoteData(Map<String, dynamic> data) async {
    if (data.isEmpty) {
      return;
    }

    final sosId = (data['sos_id'] ?? data['sos_event_id'] ?? data['event_id'])
        ?.toString();
    if (sosId == null || sosId.isEmpty) {
      return;
    }

    await _navigateToSosDetail(sosId);
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

    navigatorState.pushNamed(
      AppRouter.emergencySosDetail,
      arguments: {'sosId': sosId},
    );
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

    if (preferFullscreen) {
      await _showFullScreenAlert(item, sosId: sosId);
      await _navigateToEmergencyAlertScreen(
        sosId: sosId,
        title: (item['title'] as String?) ?? 'Canh bao khan cap',
        message:
            (item['message'] as String?) ??
            'Phat hien tinh huong khan cap. Nhan de xem chi tiet.',
      );
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

  bool _isEmergencyAlert(Map<String, dynamic> item) {
    final alertType =
        (item['alert_type'] as String?)?.toLowerCase().trim() ?? '';
    return alertType == 'sos' ||
        alertType == 'manual' ||
        alertType.contains('sos') ||
        alertType == 'fall_detected' ||
        alertType == 'fall_detection';
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
    final title = (item['title'] as String?) ?? 'Cảnh báo khẩn cấp';
    final body =
        (item['message'] as String?) ??
        'Phát hiện tình huống khẩn cấp. Nhấn để xem chi tiết.';
    final payload = jsonEncode({
      'type': 'sos',
      'sosId': sosId,
      'notificationId': item['id']?.toString(),
    });

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _fullScreenChannelId,
        _fullScreenChannelName,
        channelDescription: 'Cảnh báo SOS và té ngã toàn màn hình',
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
    final title = (item['title'] as String?) ?? 'Cảnh báo SOS bỏ lỡ';
    final body =
        (item['message'] as String?) ??
        'Bạn có một cảnh báo SOS khi chưa hoạt động trong ứng dụng.';

    final payload = jsonEncode({
      'type': 'sos',
      'sosId': sosId,
      'notificationId': item['id']?.toString(),
    });

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _missedChannelId,
        _missedChannelName,
        channelDescription: 'Thông báo SOS bị bỏ lỡ khi không online',
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
      final sosId = map['sosId']?.toString();
      if (sosId == null || sosId.isEmpty) {
        return;
      }

      await _navigateToSosDetail(sosId);
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
