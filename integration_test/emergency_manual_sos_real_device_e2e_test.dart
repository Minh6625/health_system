import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/core/routes/app_router.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';
import 'package:healthguard/features/emergency/widgets/sos_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:slide_to_act/slide_to_act.dart';

import 'helpers/emergency_e2e_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'patient manual SOS can be opened by caregiver and resolved on one device',
    (WidgetTester tester) async {
      await launchEmergencyApp(tester);
      await login(
        tester,
        email: emergencyPatientEmail,
        password: emergencyPatientPassword,
      );

      await pushNamed(tester, AppRouter.manualSos);
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('manual-sos-screen')),
      );

      final slider = tester.widget<SlideAction>(
        find.byKey(const ValueKey('manual-sos-submit-slider')),
      );
      await slider.onSubmit!();
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('sos-confirm-screen')),
      );
      expect(find.text('Đã gửi SOS'), findsOneWidget);

      await relaunchWithClearedSession(tester);
      await login(
        tester,
        email: emergencyCaregiverEmail,
        password: emergencyCaregiverPassword,
      );

      await pushWidget(
        tester,
        const EmergencySOSReceivedListScreen(enableAutoRefresh: false),
      );
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('emergency-sos-list-screen')),
      );
      await pumpUntilVisible(
        tester,
        find.byType(SOSCard).first,
        timeout: const Duration(seconds: 60),
      );

      await tester.tap(find.byType(SOSCard).first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('emergency-sos-detail-screen')),
      );

      await tester.tap(
        find.byKey(const ValueKey('emergency-sos-detail-resolve-button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await pumpUntilVisible(
        tester,
        find.byKey(const ValueKey('emergency-sos-detail-resolve-dialog')),
      );
      await tester.tap(
        find.byKey(const ValueKey('emergency-sos-detail-resolve-confirm')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await pumpUntilVisible(
        tester,
        find.textContaining('Trạng thái xử lý: safe'),
        timeout: const Duration(seconds: 30),
      );
    },
  );
}
