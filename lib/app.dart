import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:healthguard/core/constants/app_strings.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/core/theme/app_theme.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/device/providers/device_provider.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/health_monitoring/providers/vital_signs_provider.dart';
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
    _initDeepLinks();
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
    
    final isResetPassword = pathStr.contains('reset-password') || hostStr == 'reset-password' || action == 'reset-password';
    final isVerifyEmail = (pathStr.contains('verify-email') || hostStr == 'verify-email') && !isResetPassword;

    if (isVerifyEmail) {
      final code = uri.queryParameters['code'] ?? uri.queryParameters['token'];
      final email = uri.queryParameters['email'];
      
      if (code != null) {
        _routeToDeepLink(AppRouter.verifyEmail, {'code': code, 'email': email, if (action != null) 'action': action});
      }
    } else if (isResetPassword) {
      final code = uri.queryParameters['code'] ?? uri.queryParameters['token'];
      final email = uri.queryParameters['email'];
      if (code != null) {
        _routeToDeepLink(AppRouter.verifyResetOtp, {'code': code, 'email': email, if (action != null) 'action': action});
      }
    } else {
      debugPrint('[DeepLink] → No matching route found, ignoring.');
    }
    debugPrint('════════════════════════════════════════');
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => VitalSignsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SleepProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              EmergencyCaregiverProvider(EmergencyCaregiverRepository()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.start,
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) {
          // addPostFrameCallback in builder fires on every rebuild.
          // We guard with _deepLinkDispatched so the pending link is only pushed once.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_deepLinkDispatched && _pendingDeepLinkRoute != null) {
              _deepLinkDispatched = true;
              final route = _pendingDeepLinkRoute!;
              final args = _pendingDeepLinkArgs;
              _pendingDeepLinkRoute = null;
              _pendingDeepLinkArgs = null;
              // Use the same strategy as _routeToDeepLink: clear the auth
              // stack back to /start for reset-password so the user cannot
              // press Back and land on an intermediate auth screen.
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
            // Safe to remove splash screen now that routing is resolved
            FlutterNativeSplash.remove();
          });
          return child!;
        },
      ),
    );
  }
}
