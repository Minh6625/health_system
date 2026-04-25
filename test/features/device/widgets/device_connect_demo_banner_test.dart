import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_connect_demo_banner.dart';

/// Pinned regression for the Phase 5b/5c-A honest-disclosure banner.
///
/// Phase 5b only warned about the mock; Phase 5c-A also locked the final
/// pair CTA so the demo flow can no longer write a fake device into the
/// real backend. The banner copy must keep three claims so reviewers
/// cannot quietly weaken the disclosure:
///   - the flow is in demo mode
///   - the "Kết nối máy này" CTA is temporarily locked
///   - the system does not save the sample device to the user account
void main() {
  testWidgets('renders demo disclosure copy on a single info row',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeviceConnectDemoBanner(),
        ),
      ),
    );

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(
      find.textContaining('chế độ demo', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('tạm khoá', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('không lưu', findRichText: true),
      findsOneWidget,
    );
  });
}
