import 'package:flutter/material.dart';
import 'package:health_system/features/auth/screens/login_screen.dart';
import 'package:health_system/features/auth/screens/register_screen.dart';
import 'package:health_system/features/home/screens/dashboard_screen.dart';

class AppRouter {
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case login:
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }

  const AppRouter._();
}
