import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/device/widgets/device_connect/device_connect_demo_banner.dart';

/// Pinned regression for the Phase 5b honest-disclosure banner.
///
/// The full device-connect flow runs on `MockBleDiscovery` data and writes a
/// hard-coded fake MAC into the real backend on confirm. This banner is what
/// stops the UI from quietly lying to the user about what is happening, so
/// it must keep mentioning the demo nature plus the upcoming real-scan
/// version. If anyone removes either claim the test should fail.
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
      find.textContaining('thiết bị mẫu', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('quét thật', findRichText: true),
      findsOneWidget,
    );
  });
}
