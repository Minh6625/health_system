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

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
    // Remove splash screen after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<void> _initDeepLinks() async {
    // Handle initial deep link when app is opened from link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Handle deep links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Error listening to deep links: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    // Handle healthguard://verify-email?token=xxx
    if (uri.host == 'verify-email') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _navigatorKey.currentState?.pushNamed(
          AppRouter.verifyEmail,
          arguments: {'token': token},
        );
      }
    }
    // Handle healthguard://reset-password?token=xxx
    else if (uri.host == 'reset-password') {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _navigatorKey.currentState?.pushNamed(
          AppRouter.resetPassword,
          arguments: {'token': token},
        );
      }
    }
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
      ),
    );
  }
}
