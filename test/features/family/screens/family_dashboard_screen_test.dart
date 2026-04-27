import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/screens/family_dashboard_screen.dart';

// Phase 10 (W6) regression: pin the auto-refresh interval default so a future
// contributor cannot quietly drop it back to 1 second and re-introduce the
// caregiver-battery-drain bug. Tests that need a different cadence keep
// using the existing `autoRefreshInterval:` ctor argument.
void main() {
  group('FamilyDashboardScreen polling cadence', () {
    test('default autoRefreshInterval is 15 seconds', () {
      const screen = FamilyDashboardScreen();
      expect(screen.autoRefreshInterval, const Duration(seconds: 15));
    });

    test('enableAutoRefresh defaults to true so the production cadence runs',
        () {
      const screen = FamilyDashboardScreen();
      expect(screen.enableAutoRefresh, isTrue);
    });

    test('autoRefreshInterval is overridable through the ctor', () {
      const screen = FamilyDashboardScreen(
        autoRefreshInterval: Duration(milliseconds: 50),
      );
      expect(screen.autoRefreshInterval, const Duration(milliseconds: 50));
    });
  });
}
