import 'package:flutter/material.dart';
import 'package:health_system/core/constants/app_strings.dart';
import 'package:health_system/core/routes/app_router.dart';
import 'package:health_system/core/theme/app_theme.dart';
import 'package:health_system/features/auth/providers/auth_provider.dart';
import 'package:health_system/features/auth/repositories/auth_repository.dart';
import 'package:provider/provider.dart';

class HealthSystemApp extends StatelessWidget {
  const HealthSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(AuthRepository()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        initialRoute: AppRouter.start,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
