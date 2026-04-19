import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:healthguard/core/constants/app_strings.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/core/theme/app_theme.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/screens/auth_pages_screen.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
// ignore: unused_import — giữ để dễ switch sang real backend
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/emergency/services/sos_realtime_alert_service.dart';
import 'package:healthguard/features/home/providers/home_dashboard_provider.dart';
import 'package:healthguard/features/family/providers/family_dashboard_provider.dart';
import 'package:healthguard/features/profile/providers/profile_provider.dart';
import 'package:healthguard/features/sleep_analysis/providers/sleep_provider.dart';
import 'package:provider/provider.dart';

class HealthSystemApp extends StatefulWidget {
  const HealthSystemApp({super.key});

  @override
  State<HealthSystemApp> createState() => _HealthSystemAppState();
}

class _HealthSystemAppState extends State<HealthSystemApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SOSRealtimeAlertService _sosRealtimeAlertService =
      SOSRealtimeAlertService.instance;
  final AuthProvider _authProvider = AuthProvider(AuthRepository());
  late final Future<bool> _bootstrapAuthFuture;
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  String? _pendingDeepLinkRoute;
  Map<String, dynamic>? _pendingDeepLinkArgs;
  bool _deepLinkDispatched = false;
  // Tracks the last handled URI so the uriLinkStream doesn't re-handle
  // the same URI that getInitialLink() already processed on cold start.
  String? _lastHandledUri;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _bootstrapAuthFuture = _authProvider.bootstrapSession();
    unawaited(_sosRealtimeAlertService.initialize(navigatorKey: _navigatorKey));
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_deepLinkDispatched && _pendingDeepLinkRoute != null) {
        _deepLinkDispatched = true;
        final route = _pendingDeepLinkRoute!;
        final args = _pendingDeepLinkArgs;
        _pendingDeepLinkRoute = null;
        _pendingDeepLinkArgs = null;
        if (route == AppRouter.verifyResetOtp) {
          _navigatorKey.currentState?.pushNamedAndRemoveUntil(
            route,
            (r) => r.settings.name == AppRouter.start,
            arguments: args,
          );
        } else {
          _navigatorKey.currentState?.pushNamed(route, arguments: args);
        }
      }
      if (!kIsWeb) {
        try {
          FlutterNativeSplash.remove();
        } catch (e) {
          debugPrint('Splash remove skipped: $e');
        }
      }
      debugPrint("==== SPLASH REMOVED IN INITSTATE ====");
    });
  }

  Future<void> _initDeepLinks() async {
    // Handle initial deep link when app is opened from link (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _lastHandledUri = initialUri.toString();
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      // debugPrint('Error getting initial link: $e');
    }

    // Handle deep links when app is already running.
    // Skip the URI if it's the same as the initial link (app_links fires it
    // via both getInitialLink and the stream on Android cold start).
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        final uriStr = uri.toString();
        if (uriStr == _lastHandledUri) {
          _lastHandledUri = null; // reset so future same-URL links work
          return;
        }
        _lastHandledUri = uriStr;
        _handleDeepLink(uri);
      },
      onError: (err) {
        // debugPrint('Error listening to deep links: $err');
      },
    );
  }

  void _routeToDeepLink(String routeName, Map<String, dynamic> arguments) {
    if (_navigatorKey.currentState?.mounted == true) {
      if (routeName == AppRouter.verifyResetOtp) {
        // For password reset: clear the entire auth stack back to /start.
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          routeName,
          (route) => route.settings.name == AppRouter.start,
          arguments: arguments,
        );
      } else {
        // For other deep links (e.g. verifyEmail): regular push
        _navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
      }
    } else {
      // Navigator not mounted yet (cold start) — store for after first frame.
      _pendingDeepLinkRoute = routeName;
      _pendingDeepLinkArgs = arguments;
    }
  }

  void _handleDeepLink(Uri uri) {
    final action = uri.queryParameters['action'];
    final pathStr = uri.path.toLowerCase();
    final hostStr = uri.host.toLowerCase();

    final isResetPassword =
        pathStr.contains('reset-password') ||
        hostStr == 'reset-password' ||
        action == 'reset-password';
    final isVerifyEmail =
        (pathStr.contains('verify-email') || hostStr == 'verify-email') &&
        !isResetPassword;

    if (isVerifyEmail) {
      final code = uri.queryParameters['code'] ?? uri.queryParameters['token'];
      final email = uri.queryParameters['email'];

      if (code != null) {
        _routeToDeepLink(AppRouter.verifyEmail, {
          'code': code,
          'email': email,
          // ignore: use_null_aware_elements
          if (action != null) 'action': action,
        });
      }
    } else if (isResetPassword) {
      final code = uri.queryParameters['code'] ?? uri.queryParameters['token'];
      final email = uri.queryParameters['email'];
      if (code != null) {
        _routeToDeepLink(AppRouter.verifyResetOtp, {
          'code': code,
          'email': email,
          // ignore: use_null_aware_elements
          if (action != null) 'action': action,
        });
      }
    } else {
      debugPrint('[DeepLink] → No matching route found, ignoring.');
    }
    debugPrint('════════════════════════════════════════');
  }

  @override
  void dispose() {
    unawaited(_sosRealtimeAlertService.dispose());
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => SleepProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => HomeDashboardProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FamilyDashboardProvider()),
        ChangeNotifierProvider(
          create: (_) => EmergencyCaregiverProvider(
            // ✅ Using live API - backend ready
            EmergencyCaregiverRepository(),
          ),
        ),
      ],
      child: _SOSAlertAuthBridge(
        service: _sosRealtimeAlertService,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: AppStrings.appName,
          theme: AppTheme.lightTheme,
          home: AuthBootstrapGate(bootstrapFuture: _bootstrapAuthFuture),
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}

class AuthBootstrapGate extends StatelessWidget {
  const AuthBootstrapGate({
    super.key,
    required this.bootstrapFuture,
    this.authenticatedBuilder,
    this.unauthenticatedBuilder,
    this.loadingBuilder,
  });

  final Future<bool> bootstrapFuture;
  final WidgetBuilder? authenticatedBuilder;
  final WidgetBuilder? unauthenticatedBuilder;
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: bootstrapFuture,
      builder: (context, snapshot) {
        final authProvider = context.watch<AuthProvider>();
        if (!authProvider.sessionResolved ||
            snapshot.connectionState == ConnectionState.waiting) {
          return loadingBuilder?.call(context) ??
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
        }

        if (authProvider.isAuthenticated) {
          return authenticatedBuilder?.call(context) ??
              const HomeDashboardScreen();
        }

        return unauthenticatedBuilder?.call(context) ??
            const AuthPagesScreen();
      },
    );
  }
}

class _SOSAlertAuthBridge extends StatefulWidget {
  const _SOSAlertAuthBridge({required this.service, required this.child});

  final SOSRealtimeAlertService service;
  final Widget child;

  @override
  State<_SOSAlertAuthBridge> createState() => _SOSAlertAuthBridgeState();
}

class _SOSAlertAuthBridgeState extends State<_SOSAlertAuthBridge> {
  AuthProvider? _authProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProvider = context.read<AuthProvider>();
    if (identical(nextProvider, _authProvider)) {
      return;
    }

    _authProvider?.removeListener(_onAuthChanged);
    _authProvider = nextProvider;
    _authProvider?.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final authProvider = _authProvider;
    if (authProvider == null) {
      return;
    }

    unawaited(
      widget.service.onAuthStateChanged(
        isAuthenticated:
            authProvider.sessionResolved && authProvider.isAuthenticated,
      ),
    );
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
