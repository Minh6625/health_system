import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/app.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:healthguard/features/notifications/services/notification_runtime_service.dart';
import 'package:healthguard/shared/presentation/shell/main_scaffold_shell.dart';

import 'e2e_test_config.dart';

const emergencyPatientEmail = 'e2e.dashboard.patient@example.com';
const emergencyPatientPassword = 'PatientE2E!123';
const emergencyCaregiverEmail = 'e2e.dashboard.caregiver@example.com';
const emergencyCaregiverPassword = 'CaregiverE2E!123';

Finder textFieldWithLabel(String label) {
  final fields = find.byType(TextFormField);
  return switch (label) {
    'Email' => fields.first,
    'Mật khẩu' => fields.last,
    _ => fields,
  };
}

String _visibleTextDebugDump(WidgetTester tester) {
  final values = <String>{};

  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data ?? widget.textSpan?.toPlainText();
    final normalized = text?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      values.add(normalized);
    }
  }

  return values.isEmpty ? '<no visible Text widgets>' : values.join(' | ');
}

Future<void> pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  Duration step = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> launchEmergencyApp(WidgetTester tester) async {
  await AuthSessionService.shared.clearSession();
  await loadE2ETestConfig(mockDevice: false);
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
    notificationFirebaseMessagingBackgroundHandler,
  );
  await tester.pumpWidget(const HealthSystemApp());
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> openLoginForm(WidgetTester tester) async {
  final startButton = find.text('Bắt đầu ngay');
  await pumpUntilVisible(tester, startButton);
  await tester.tap(startButton);
  await tester.pump(const Duration(milliseconds: 500));
  await pumpUntilVisible(tester, textFieldWithLabel('Email'));
}

Future<void> login(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await openLoginForm(tester);
  await tester.enterText(textFieldWithLabel('Email'), email);
  await tester.enterText(textFieldWithLabel('Mật khẩu'), password);
  final loginButton = find.widgetWithText(ElevatedButton, 'ĐĂNG NHẬP');
  tester.widget<ElevatedButton>(loginButton).onPressed!.call();
  await tester.pump(const Duration(milliseconds: 300));

  final dashboardShell = find.byType(MainScaffoldShell);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (dashboardShell.evaluate().isNotEmpty) {
      return;
    }
  }

  fail(
    'Timed out waiting for authenticated dashboard shell. '
    'Visible texts: ${_visibleTextDebugDump(tester)}',
  );
}

Future<void> relaunchWithClearedSession(WidgetTester tester) async {
  await AuthSessionService.shared.clearSession();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 200));
  await launchEmergencyApp(tester);
}

Future<void> pushNamed(
  WidgetTester tester,
  String route, {
  Map<String, dynamic>? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pushNamed(route, arguments: arguments);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> pushWidget(WidgetTester tester, Widget widget) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.push(MaterialPageRoute<void>(builder: (_) => widget));
  await tester.pump(const Duration(milliseconds: 300));
}
