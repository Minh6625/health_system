import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/emergency/models/sos_event_model.dart';
import 'package:healthguard/features/emergency/providers/emergency_caregiver_provider.dart';
import 'package:healthguard/features/emergency/repositories/emergency_caregiver_repository.dart';
import 'package:healthguard/features/family/models/access_profile_model.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';
import 'package:healthguard/features/family/providers/family_dashboard_provider.dart';
import 'package:healthguard/features/family/providers/family_relationship_provider.dart';
import 'package:healthguard/features/family/screens/family_shell_screen.dart';
import 'package:provider/provider.dart';

import '../test_support/fake_family_repository.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super(AuthRepository()) {
    accessToken = 'token';
    sessionResolved = true;
    currentUser = UserData(
      userId: 7,
      email: 'caregiver@example.com',
      fullName: 'Caregiver',
      role: 'user',
    );
  }
}

class _FakeEmergencyCaregiverRepository extends EmergencyCaregiverRepository {
  @override
  Future<SOSAlertsResult> getSOSAlerts({required String status}) async {
    return const SOSAlertsResult(
      sosAlerts: <SOSEventModel>[],
      totalCount: 0,
      activeCount: 0,
      resolvedCount: 0,
    );
  }
}

Widget _buildShell(FakeFamilyRepository repository) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuthProvider()),
      ChangeNotifierProvider(
        create: (_) => FamilyRelationshipProvider(repository: repository),
      ),
      ChangeNotifierProvider(
        create: (_) => FamilyDashboardProvider(repository: repository),
      ),
      ChangeNotifierProvider(
        create:
            (_) => EmergencyCaregiverProvider(
              _FakeEmergencyCaregiverRepository(),
            ),
      ),
    ],
    child: const MaterialApp(
      home: FamilyShellScreen(
        enableAutoRefresh: false,
        badgeRefreshInterval: Duration(days: 1),
      ),
    ),
  );
}

void main() {
  // Phase 10 (W6) regression: pin the badge polling cadence default so a
  // future contributor cannot quietly drop it back to 2 seconds. Tab badges
  // already refresh on tab change and on push events; this timer is just
  // the recovery fallback.
  group('FamilyShellScreen badge cadence', () {
    test('default badgeRefreshInterval is 30 seconds', () {
      const screen = FamilyShellScreen();
      expect(screen.badgeRefreshInterval, const Duration(seconds: 30));
    });

    test('enableAutoRefresh defaults to true', () {
      const screen = FamilyShellScreen();
      expect(screen.enableAutoRefresh, isTrue);
    });

    test('badgeRefreshInterval is overridable through the ctor', () {
      const screen = FamilyShellScreen(
        badgeRefreshInterval: Duration(milliseconds: 50),
      );
      expect(screen.badgeRefreshInterval, const Duration(milliseconds: 50));
    });
  });

  testWidgets(
    'family shell hides SOS tab when no linked profile can receive alerts',
    (tester) async {
      final repository = FakeFamilyRepository(
        relationships: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 92,
            'patient_id': 15,
            'patient_name': 'Binh Tran',
            'patient_email': 'binh@example.com',
            'caregiver_id': 7,
            'caregiver_name': 'Caregiver',
            'caregiver_email': 'caregiver@example.com',
            'relationship_type': 'family',
            'status': 'accepted',
            'primary_relationship_label': 'Bố',
            'tags': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'family', 'name': 'Gia đình'},
            ],
            'can_view_vitals': true,
            'can_receive_alerts': false,
            'can_view_location': true,
            'has_view_vitals_permission': false,
          },
        ],
        accessProfiles: const <AccessProfileModel>[
          AccessProfileModel(
            id: 7,
            fullName: 'Caregiver',
            relationshipType: 'self',
            canViewVitals: true,
            canReceiveAlerts: true,
            canViewLocation: true,
          ),
          AccessProfileModel(
            id: 15,
            fullName: 'Binh Tran',
            relationshipType: 'family',
            canViewVitals: true,
            canReceiveAlerts: false,
            canViewLocation: true,
          ),
        ],
        dashboard: <FamilyProfileSnapshot>[
          FamilyProfileSnapshot(
            id: '15',
            name: 'Binh',
            relation: 'Bố',
            isSosActive: false,
            lastUpdated: DateTime(2026, 4, 23),
          ),
        ],
      );

      await tester.pumpWidget(_buildShell(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('family-shell-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-tab-dashboard')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-tab-contacts')), findsOneWidget);
      expect(find.byKey(const ValueKey('family-tab-sos')), findsNothing);
    },
  );

  testWidgets(
    'family shell shows SOS tab when linked profile can receive alerts',
    (tester) async {
      final repository = FakeFamilyRepository(
        relationships: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 93,
            'patient_id': 15,
            'patient_name': 'Binh Tran',
            'patient_email': 'binh@example.com',
            'caregiver_id': 7,
            'caregiver_name': 'Caregiver',
            'caregiver_email': 'caregiver@example.com',
            'relationship_type': 'family',
            'status': 'accepted',
            'primary_relationship_label': 'Bố',
            'tags': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'family', 'name': 'Gia đình'},
            ],
            'can_view_vitals': true,
            'can_receive_alerts': true,
            'can_view_location': true,
            'has_view_vitals_permission': false,
          },
        ],
        accessProfiles: const <AccessProfileModel>[
          AccessProfileModel(
            id: 7,
            fullName: 'Caregiver',
            relationshipType: 'self',
            canViewVitals: true,
            canReceiveAlerts: true,
            canViewLocation: true,
          ),
          AccessProfileModel(
            id: 15,
            fullName: 'Binh Tran',
            relationshipType: 'family',
            canViewVitals: true,
            canReceiveAlerts: true,
            canViewLocation: true,
          ),
        ],
      );

      await tester.pumpWidget(_buildShell(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('family-tab-sos')), findsOneWidget);
    },
  );
}
