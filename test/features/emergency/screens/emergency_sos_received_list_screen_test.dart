import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/emergency/screens/emergency_sos_received_list_screen.dart';

// Phase 10 (W6) regression: lock the SOS list polling cadence so a future
// contributor cannot quietly drop it back to 2 seconds. SOS arrives over
// the realtime push channel; this timer is just a recovery fallback.
void main() {
  group('EmergencySOSReceivedListScreen polling cadence', () {
    test('default autoRefreshInterval is 10 seconds', () {
      const screen = EmergencySOSReceivedListScreen();
      expect(screen.autoRefreshInterval, const Duration(seconds: 10));
    });

    test('enableAutoRefresh defaults to true', () {
      const screen = EmergencySOSReceivedListScreen();
      expect(screen.enableAutoRefresh, isTrue);
    });

    test('autoRefreshInterval is overridable through the ctor', () {
      const screen = EmergencySOSReceivedListScreen(
        autoRefreshInterval: Duration(milliseconds: 50),
      );
      expect(screen.autoRefreshInterval, const Duration(milliseconds: 50));
    });
  });
}
