import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:healthguard/features/auth/screens/auth_pages_screen.dart';
import 'package:healthguard/features/auth/screens/change_password_screen.dart';
import 'package:healthguard/features/auth/screens/forgot_password_screen.dart';
import 'package:healthguard/features/auth/screens/login_screen.dart';
import 'package:healthguard/features/auth/screens/register_screen.dart';
import 'package:healthguard/features/auth/screens/reset_otp_verification_screen.dart';
import 'package:healthguard/features/auth/screens/reset_password_screen.dart';
import 'package:healthguard/features/auth/screens/start_screen.dart';
import 'package:healthguard/features/auth/screens/email_verification_screen.dart';
import 'package:healthguard/features/home/screens/main_screen.dart';
import 'package:healthguard/features/profile/screens/edit_profile_screen.dart';

class AppRouter {
  static const String start = '/start';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String verifyResetOtp = '/verify-reset-otp';
  static const String resetPassword = '/reset-password';
  static const String changePassword = '/change-password';
  static const String editProfile = '/edit-profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    String routePath = settings.name ?? login;
    Map<String, dynamic> routeArgs = {};
    if (settings.arguments != null) {
      routeArgs = Map<String, dynamic>.from(settings.arguments as Map);
    }

    // Intercept native Flutter deep link pushes which include query parameters in the route name
    if (routePath.contains('?')) {
      final uri = Uri.tryParse(routePath);
      if (uri != null) {
        routePath = uri.path;
        routeArgs.addAll(uri.queryParameters);
        final action = routeArgs['action'];
        final pathStr = routePath.toLowerCase();
        final hostStr = uri.host.toLowerCase();
        
        final isResetPassword = pathStr.contains('reset-password') || hostStr == 'reset-password' || action == 'reset-password';
        final isVerifyEmail = (pathStr.contains('verify-email') || hostStr == 'verify-email') && !isResetPassword;

        // If the path is empty or just '/', we need to deduce the intent from the query parameters
        if (routePath.isEmpty || routePath == '/') {
          if (uri.host.isNotEmpty) {
            routePath = '/${uri.host}';
          } else {
            // Fallback heuristics based on action or default to verifyEmail if code is present
            if (isResetPassword) {
              routePath = verifyResetOtp;
            } else if (routeArgs.containsKey('code') || isVerifyEmail) {
              routePath = verifyEmail;
            }
          }
        }

        // Final forceful override just in case
        if (isResetPassword) {
          routePath = verifyResetOtp;
        } else if (isVerifyEmail) {
          routePath = verifyEmail;
        }
      }
    }

    switch (routePath) {
      case dashboard:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case verifyEmail:
        return MaterialPageRoute(
          settings: RouteSettings(name: verifyEmail, arguments: routeArgs),
          builder: (_) => EmailVerificationScreen(
            email: routeArgs['email'] as String? ?? 'Email của bạn',
            code: routeArgs['code'] as String?,
          ),
        );
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case verifyResetOtp:
        return MaterialPageRoute(
          settings: RouteSettings(name: verifyResetOtp, arguments: routeArgs),
          builder: (_) => ResetOtpVerificationScreen(
            email: routeArgs['email'] as String? ?? '',
            code: routeArgs['code'] as String?,
          ),
        );
      case resetPassword:
        return MaterialPageRoute(
          settings: RouteSettings(name: resetPassword, arguments: routeArgs),
          builder: (_) => ResetPasswordScreen(
            code: routeArgs['code'] as String?,
            email: routeArgs['email'] as String?,
          ),
        );
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case start:
        return MaterialPageRoute(builder: (_) => const AuthPagesScreen());
      case login:
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }

  const AppRouter._();
}
