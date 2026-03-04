import 'package:flutter/material.dart';
import 'package:healthguard/features/auth/screens/change_password_screen.dart';
import 'package:healthguard/features/auth/screens/forgot_password_screen.dart';
import 'package:healthguard/features/auth/screens/login_screen.dart';
import 'package:healthguard/features/auth/screens/register_screen.dart';
import 'package:healthguard/features/auth/screens/reset_password_screen.dart';
import 'package:healthguard/features/auth/screens/start_screen.dart';
import 'package:healthguard/features/auth/screens/verify_email_screen.dart';
import 'package:healthguard/features/home/screens/dashboard_screen.dart';

class AppRouter {
  static const String start = '/start';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String verifyEmail = '/verify-email';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String changePassword = '/change-password';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case verifyEmail:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            token: args?['token'] as String?,
            email: args?['email'] as String?,
          ),
        );
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case resetPassword:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            resetToken: args?['token'] as String?,
            email: args?['email'] as String?,
          ),
        );
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case start:
        return MaterialPageRoute(builder: (_) => const StartScreen());
      case login:
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }

  const AppRouter._();
}
