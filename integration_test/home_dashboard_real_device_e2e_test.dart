import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/app.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/features/home/presentation/widgets/risk_insight_card.dart';
import 'package:healthguard/features/analysis/presentation/widgets/risk_history_item_card.dart';
import 'package:integration_test/integration_test.dart';

const _patientEmail = 'e2e.dashboard.patient@example.com';
const _patientPassword = 'PatientE2E!123';
const _caregiverEmail = 'e2e.dashboard.caregiver@example.com';
const _caregiverPassword = 'CaregiverE2E!123';
const _testApiUrl = 'http://127.0.0.1:8000/api/v1/mobile';

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
  dotenv.testLoad(fileInput: 'API_URL=$_testApiUrl\nMOCK_DEVICE=false');
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
  await tester.tap(find.text('ĐĂNG NHẬP'));
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilVisible(tester, find.text('Điểm sức khoẻ hôm nay'));
}

Future<void> _pageBack(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _activateButton<T extends ButtonStyleButton>(
  WidgetTester tester,
  Finder finder,
) async {
  tester.widget<T>(finder).onPressed!.call();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openRiskFlowFromDashboard(WidgetTester tester) async {
  final riskCard = find.byType(RiskInsightCard);
  await _pumpUntilVisible(tester, riskCard);
  await tester.ensureVisible(riskCard);
  await tester.tap(riskCard, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilVisible(tester, find.text('Báo cáo rủi ro sức khỏe'));
}

Future<void> _assertRiskDetailAndDrilldowns(WidgetTester tester) async {
  await tester.tap(find.text('Xem giải thích AI'));
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilVisible(tester, find.text('Giải thích báo cáo rủi ro'));

  await tester.scrollUntilVisible(
    find.text('Chi tiết\nChỉ số HT'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.widgetWithText(OutlinedButton, 'Chi tiết\nChỉ số HT'));
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilVisible(tester, find.text('Nhịp tim'));
  await _pageBack(tester);
  await _pumpUntilVisible(tester, find.text('Giải thích báo cáo rủi ro'));

  await tester.scrollUntilVisible(
    find.text('Báo cáo\nGiấc ngủ'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.widgetWithText(OutlinedButton, 'Báo cáo\nGiấc ngủ'));
  await tester.pump(const Duration(milliseconds: 300));
  await _pumpUntilVisible(tester, find.text('Báo cáo Giấc ngủ'));
  await _pageBack(tester);
  await _pumpUntilVisible(tester, find.text('Giải thích báo cáo rủi ro'));
}

Future<void> _assertRiskHistory(WidgetTester tester) async {
  await _pageBack(tester);
  await _pumpUntilVisible(tester, find.text('Báo cáo rủi ro sức khỏe'));
  final historyButton = find.widgetWithText(OutlinedButton, 'Xem lịch sử');
  await tester.scrollUntilVisible(
    historyButton,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(historyButton);
  await _activateButton<OutlinedButton>(tester, historyButton);
  await _pumpUntilVisible(tester, find.text('Lịch sử đánh giá rủi ro'));

  await tester.tap(find.text('30 ngày'));
  await tester.pump(const Duration(milliseconds: 350));
  await _pumpUntilVisible(tester, find.text('Lịch sử đánh giá rủi ro'));

  await tester.tap(find.text('90 ngày'));
  await tester.pump(const Duration(milliseconds: 350));
  await _pumpUntilVisible(tester, find.text('Lịch sử đánh giá rủi ro'));

  final historyCard = find.byType(RiskHistoryItemCard);
  if (historyCard.evaluate().isNotEmpty) {
    await tester.tap(historyCard.first);
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntilVisible(tester, find.text('Giải thích báo cáo rủi ro'));
  }
}

Future<String> _loadFirstLinkedProfileId(WidgetTester tester) async {
  final profiles = await tester.runAsync(
    () => FamilyRepository().getFamilyDashboard(),
  );
  if (profiles == null || profiles.isEmpty) {
    fail('Expected at least one linked profile for caregiver E2E test.');
  }
  return profiles.first.id;
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

  group('Home Dashboard real-device E2E', () {
    testWidgets(
      'patient self profile flow reaches risk, detail, history, and sleep',
      (WidgetTester tester) async {
        await _launchApp(tester);
        await _login(tester, email: _patientEmail, password: _patientPassword);

        expect(find.text('Điểm sức khoẻ hôm nay'), findsOneWidget);

        await _openRiskFlowFromDashboard(tester);
        await _assertRiskDetailAndDrilldowns(tester);
        await _assertRiskHistory(tester);
      },
    );

    testWidgets(
      'caregiver linked profile flow reaches linked dashboard detail and history',
      (WidgetTester tester) async {
        await _launchApp(tester);
        await _login(
          tester,
          email: _caregiverEmail,
          password: _caregiverPassword,
        );

        final linkedProfileId = await _loadFirstLinkedProfileId(tester);
        await _pushNamed(
          tester,
          AppRouter.dashboard,
          arguments: {'profileId': linkedProfileId},
        );
        expect(find.text('Điểm sức khoẻ hôm nay'), findsOneWidget);

        await _openRiskFlowFromDashboard(tester);
        await _pumpUntilVisible(tester, find.text('Hồ sơ người thân'));
        await _assertRiskDetailAndDrilldowns(tester);
        await _assertRiskHistory(tester);
      },
    );
  });
}
