import 'package:flutter/material.dart';
import 'package:healthguard/features/auth/screens/auth_pages_screen.dart';
import 'package:healthguard/features/auth/screens/change_password_screen.dart';
import 'package:healthguard/features/auth/screens/forgot_password_screen.dart';
import 'package:healthguard/features/auth/screens/login_screen.dart';
import 'package:healthguard/features/auth/screens/register_screen.dart';
import 'package:healthguard/features/auth/screens/reset_otp_verification_screen.dart';
import 'package:healthguard/features/auth/screens/reset_password_screen.dart';
import 'package:healthguard/features/auth/screens/email_verification_screen.dart';
import 'package:healthguard/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:healthguard/features/profile/screens/edit_profile_screen.dart';
import 'package:healthguard/features/profile/screens/medical_info_screen.dart';
import 'package:healthguard/features/profile/screens/delete_account_screen.dart';
import 'package:healthguard/features/profile/screens/profile_shell_screen.dart';
import 'package:healthguard/features/family/screens/family_shell_screen.dart';
import 'package:healthguard/features/family/screens/family_dashboard_screen.dart';
import 'package:healthguard/features/family/screens/add_contact_screen.dart';
import 'package:healthguard/features/family/screens/linked_contact_detail_screen.dart';
import 'package:healthguard/features/family/screens/person_detail_screen.dart';
import 'package:healthguard/features/device/screens/device_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_report_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_detail_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_history_screen.dart';
import 'package:healthguard/features/sleep_analysis/screens/sleep_settings_screen.dart';
import 'package:healthguard/features/health_monitoring/screens/health_report_screen.dart';
import 'package:healthguard/features/health_monitoring/screens/vital_detail_screen.dart';
import 'package:healthguard/features/emergency/screens/manual_sos_screen.dart';
import 'package:healthguard/features/emergency/screens/sos_confirm_screen.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_detail_screen.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_report_screen.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_report_detail_screen.dart';
import 'package:healthguard/features/analysis/presentation/screens/risk_history_screen.dart';
import 'package:healthguard/features/analysis/providers/risk_report_provider.dart';
import 'package:healthguard/features/analysis/providers/risk_history_provider.dart';
import 'package:healthguard/features/analysis/repositories/risk_analysis_repository.dart';
import 'package:healthguard/features/notifications/screens/notifications_screen.dart';
import 'package:healthguard/features/home/providers/home_dashboard_provider.dart';
import 'package:provider/provider.dart';

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
  static const String profile = '/profile';
  static const String medicalInfo = '/medical-info';
  static const String deleteAccount = '/delete-account';
  static const String familyManagement = '/family-management';
  static const String device = '/device';
  static const String sleepReport = '/sleep-report';
  static const String sleepDetail = '/sleep-detail';
  static const String sleepHistory = '/sleep-history';
  static const String sleepSettings = '/sleep-settings';
  static const String vitalDetail = '/vital-detail';
  static const String healthReport = '/health-report';
  static const String addContact = '/add-contact';
  static const String linkedContactDetail = '/linked-contact-detail';
  static const String familyDashboard = '/family-dashboard';
  static const String personDetail = '/person-detail';
  static const String manualSos = '/manual-sos';
  static const String sosConfirm = '/sos-confirm';
  static const String emergencySosDetail = '/emergency/sos/detail';
  static const String riskReport = '/risk-report';
  static const String riskReportDetail = '/risk-report-detail';
  static const String riskHistory = '/risk-history';
  static const String notifications = '/notifications';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    String routePath = settings.name ?? login;
    debugPrint("======== [AppRouter] onGenerateRoute: $routePath ========");

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

        final isResetPassword =
            pathStr.contains('reset-password') ||
            hostStr == 'reset-password' ||
            action == 'reset-password';
        final isVerifyEmail =
            (pathStr.contains('verify-email') || hostStr == 'verify-email') &&
            !isResetPassword;

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
        final profileId = routeArgs['profileId'] as String?;
        final isSelfProfile =
            profileId == null || profileId.isEmpty || profileId == 'self';
        if (isSelfProfile) {
          return MaterialPageRoute(builder: (_) => const HomeDashboardScreen());
        }
        return MaterialPageRoute(
          settings: RouteSettings(name: dashboard, arguments: routeArgs),
          builder: (_) => ChangeNotifierProvider(
            create: (_) => HomeDashboardProvider(profileId: profileId),
            child: HomeDashboardScreen(profileId: profileId),
          ),
        );
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
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileShellScreen());
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case medicalInfo:
        return MaterialPageRoute(builder: (_) => const MedicalInfoScreen());
      case deleteAccount:
        return MaterialPageRoute(builder: (_) => const DeleteAccountScreen());
      case familyManagement:
        return MaterialPageRoute(
          builder: (_) => FamilyShellScreen(
            initialTab: (routeArgs['initialTab'] as int?) ?? 0,
          ),
        );
      case addContact:
        return MaterialPageRoute(builder: (_) => const AddContactScreen());
      case familyDashboard:
        return MaterialPageRoute(builder: (_) => const FamilyDashboardScreen());
      case linkedContactDetail:
        final contactId = routeArgs['contactId']?.toString() ?? '';
        return MaterialPageRoute(
          settings: RouteSettings(
            name: linkedContactDetail,
            arguments: routeArgs,
          ),
          builder: (_) => LinkedContactDetailScreen(contactId: contactId),
        );
      case personDetail:
        return MaterialPageRoute(
          settings: RouteSettings(name: personDetail, arguments: routeArgs),
          builder: (_) => PersonDetailScreen(
            profileId: routeArgs['profileId'] as String? ?? '1',
          ),
        );
      case device:
        return MaterialPageRoute(builder: (_) => const DeviceScreen());
      case sleepReport:
        return MaterialPageRoute(
          settings: RouteSettings(name: sleepReport, arguments: routeArgs),
          builder: (_) => SleepReportScreen(
            profileId: routeArgs['profileId'] as String?,
            date: routeArgs['date'] as DateTime?,
          ),
        );
      case sleepDetail:
        return MaterialPageRoute(
          settings: RouteSettings(name: sleepDetail, arguments: routeArgs),
          builder: (_) => SleepDetailScreen(
            profileId: routeArgs['profileId'] as String?,
            date: routeArgs['date'] as DateTime?,
          ),
        );
      case sleepHistory:
        return MaterialPageRoute(
          settings: RouteSettings(name: sleepHistory, arguments: routeArgs),
          builder: (_) =>
              SleepHistoryScreen(profileId: routeArgs['profileId'] as String?),
        );
      case sleepSettings:
        return MaterialPageRoute(builder: (_) => const SleepSettingsScreen());
      case vitalDetail:
        return MaterialPageRoute(
          settings: RouteSettings(name: vitalDetail, arguments: routeArgs),
          builder: (_) => VitalDetailScreen(
            vitalType: routeArgs['vitalType'] as String? ?? 'hr',
            profileId: routeArgs['profileId'] as String?,
          ),
        );
      case healthReport:
        return MaterialPageRoute(
          settings: RouteSettings(name: healthReport, arguments: routeArgs),
          builder: (_) => HealthReportScreen(
            profileId: routeArgs['profileId'] as String?,
          ),
        );
      case manualSos:
        return MaterialPageRoute(builder: (_) => ManualSOSScreen());
      case sosConfirm:
        return MaterialPageRoute(
          builder: (_) => SosConfirmScreen(
            recipientCount: routeArgs['recipientCount'] as int? ?? 1,
          ),
        );
      case emergencySosDetail:
        return MaterialPageRoute(
          settings: RouteSettings(
            name: emergencySosDetail,
            arguments: routeArgs,
          ),
          builder: (_) => EmergencySOSDetailScreen(
            sosId: routeArgs['sosId'] as String? ?? '',
          ),
        );
      case riskReport:
        return MaterialPageRoute(
          settings: RouteSettings(name: riskReport, arguments: routeArgs),
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                RiskReportProvider(repository: RiskAnalysisRepository()),
            child: RiskReportScreen(
              profileId: routeArgs['profileId'] as String?,
            ),
          ),
        );
      case riskReportDetail:
        return MaterialPageRoute(
          settings: RouteSettings(name: riskReportDetail, arguments: routeArgs),
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                RiskReportProvider(repository: RiskAnalysisRepository()),
            child: RiskReportDetailScreen(
              reportId:
                  int.tryParse(routeArgs['reportId']?.toString() ?? '') ?? 0,
              profileId: routeArgs['profileId'] as String?,
            ),
          ),
        );
      case riskHistory:
        return MaterialPageRoute(
          settings: RouteSettings(name: riskHistory, arguments: routeArgs),
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                RiskHistoryProvider(repository: RiskAnalysisRepository()),
            child: RiskHistoryScreen(
              profileId: routeArgs['profileId'] as String?,
            ),
          ),
        );
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case start:
        return MaterialPageRoute(builder: (_) => const AuthPagesScreen());
      case login:
      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }

  const AppRouter._();
}
