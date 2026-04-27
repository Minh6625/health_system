import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/app.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/e2e_test_config.dart';

const _caregiverEmail = 'e2e.dashboard.caregiver@example.com';
const _caregiverPassword = 'CaregiverE2E!123';

Finder _textFieldWithLabel(String label) {
  final fields = find.byType(TextFormField);
  return switch (label) {
    'Email' => fields.first,
    'Mật khẩu' => fields.last,
    _ => fields,
  };
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
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

Future<void> _launchApp(WidgetTester tester) async {
  await AuthSessionService.shared.clearSession();
  await loadE2ETestConfig(mockDevice: false);
  await tester.pumpWidget(const HealthSystemApp());
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openLoginForm(WidgetTester tester) async {
  final startButton = find.text('Bắt đầu ngay');
  await _pumpUntilVisible(tester, startButton);
  await tester.tap(startButton);
  await tester.pump(const Duration(milliseconds: 500));
  await _pumpUntilVisible(tester, _textFieldWithLabel('Email'));
}

Future<void> _login(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await _openLoginForm(tester);
  await tester.enterText(_textFieldWithLabel('Email'), email);
  await tester.enterText(_textFieldWithLabel('Mật khẩu'), password);
  final loginButton = find.widgetWithText(ElevatedButton, 'ĐĂNG NHẬP');
  tester.widget<ElevatedButton>(loginButton).onPressed!.call();
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilVisible(tester, find.byType(Navigator));
}

Future<void> _pushNamed(
  WidgetTester tester,
  String route, {
  Map<String, dynamic>? arguments,
}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pushNamed(route, arguments: arguments);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'caregiver family flow reaches contacts detail mutates and refreshes dashboard',
    (tester) async {
      await _launchApp(tester);
      await _login(
        tester,
        email: _caregiverEmail,
        password: _caregiverPassword,
      );

      await _pushNamed(
        tester,
        AppRouter.familyManagement,
        arguments: const <String, dynamic>{'initialTab': 1},
      );
      await tester.pumpAndSettle();
      await _pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('family-shell-screen')),
      );

      final relationships = await tester.runAsync(
        () => FamilyRepository().getRelationships(),
      );
      expect(relationships, isNotNull);
      final accepted = relationships!.firstWhere(
        (item) => item['status'] == 'accepted',
      );
      final relationshipId = accepted['id'].toString();
      final contactCard = find.byKey(
        ValueKey('family-contact-card-$relationshipId'),
      );

      await tester.ensureVisible(contactCard);
      await tester.tap(contactCard);
      await tester.pumpAndSettle();
      await _pumpUntilVisible(tester, find.text('Quyền chia sẻ'));

      await tester.tap(find.text('Cho phép xem vị trí của tôi khi SOS'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('family-tab-dashboard')));
      await tester.pumpAndSettle();
      await _pumpUntilVisible(
        tester,
        find.text('Quản lý liên hệ & quyền xem'),
      );
    },
  );
}
