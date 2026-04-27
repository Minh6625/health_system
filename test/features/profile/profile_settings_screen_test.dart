import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/profile/providers/clinician_audience_provider.dart';
import 'package:healthguard/features/profile/screens/profile_settings_screen.dart';

class _StubAuthProvider extends AuthProvider {
  _StubAuthProvider(super.repo, this._stubUser);

  final UserData? _stubUser;

  @override
  UserData? get currentUser => _stubUser;
}

class _NoopAuthRepository implements AuthRepository {
  @override
  noSuchMethod(Invocation invocation) {
    return null;
  }
}

UserData? _user(String role) =>
    UserData(userId: 1, email: 'u@x', fullName: 'U', role: role);

Widget _wrap({
  required UserData? user,
  required ClinicianAudienceProvider audienceProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _StubAuthProvider(_NoopAuthRepository(), user),
      ),
      ChangeNotifierProvider<ClinicianAudienceProvider>.value(
        value: audienceProvider,
      ),
    ],
    child: const MaterialApp(home: ProfileSettingsScreen()),
  );
}

void main() {
  group('ProfileSettingsScreen.isClinicianRole', () {
    test('accepts canonical clinician + admin roles', () {
      expect(ProfileSettingsScreen.isClinicianRole('clinician'), isTrue);
      expect(ProfileSettingsScreen.isClinicianRole('admin'), isTrue);
    });

    test('case-insensitive + whitespace-tolerant', () {
      expect(ProfileSettingsScreen.isClinicianRole('Clinician'), isTrue);
      expect(ProfileSettingsScreen.isClinicianRole('  ADMIN  '), isTrue);
    });

    test('rejects null + patient + unknown roles', () {
      expect(ProfileSettingsScreen.isClinicianRole(null), isFalse);
      expect(ProfileSettingsScreen.isClinicianRole(''), isFalse);
      expect(ProfileSettingsScreen.isClinicianRole('patient'), isFalse);
      expect(ProfileSettingsScreen.isClinicianRole('user'), isFalse);
      expect(ProfileSettingsScreen.isClinicianRole('caregiver'), isFalse);
    });
  });

  group('ProfileSettingsScreen widget', () {
    testWidgets('renders the toggle for a clinician user', (tester) async {
      final audience = ClinicianAudienceProvider();
      audience.debugSetState(enabled: false);

      await tester.pumpWidget(
        _wrap(user: _user('clinician'), audienceProvider: audience),
      );
      await tester.pump();

      expect(find.text('Chế độ chuyên môn'), findsOneWidget);
      // Switch present + reflects current state.
      final switchFinder = find.byType(SwitchListTile);
      expect(switchFinder, findsOneWidget);
      final switchTile = tester.widget<SwitchListTile>(switchFinder);
      expect(switchTile.value, isFalse);
    });

    testWidgets('renders the toggle for admin role too', (tester) async {
      final audience = ClinicianAudienceProvider();
      audience.debugSetState(enabled: false);

      await tester.pumpWidget(
        _wrap(user: _user('admin'), audienceProvider: audience),
      );
      await tester.pump();

      expect(find.text('Chế độ chuyên môn'), findsOneWidget);
    });

    testWidgets('hides the toggle for patient role + shows the placeholder',
        (tester) async {
      final audience = ClinicianAudienceProvider();
      audience.debugSetState(enabled: false);

      await tester.pumpWidget(
        _wrap(user: _user('patient'), audienceProvider: audience),
      );
      await tester.pump();

      expect(find.text('Chế độ chuyên môn'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      // Placeholder is rendered.
      expect(find.text('Chưa có cài đặt nâng cao'), findsOneWidget);
    });

    testWidgets('hides the toggle when the user is unauthenticated',
        (tester) async {
      final audience = ClinicianAudienceProvider();
      audience.debugSetState(enabled: false);

      await tester.pumpWidget(
        _wrap(user: null, audienceProvider: audience),
      );
      await tester.pump();

      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('switch is disabled before init resolves', (tester) async {
      final audience = ClinicianAudienceProvider();
      // Pre-init state: isInitialized=false.
      audience.debugSetState(enabled: false, isInitialized: false);

      await tester.pumpWidget(
        _wrap(user: _user('clinician'), audienceProvider: audience),
      );
      await tester.pump();

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      // ``onChanged: null`` disables the switch on Material.
      expect(switchTile.onChanged, isNull);
    });

    testWidgets('reflects post-init enabled state in the subtitle',
        (tester) async {
      final audience = ClinicianAudienceProvider();
      audience.debugSetState(enabled: true);

      await tester.pumpWidget(
        _wrap(user: _user('clinician'), audienceProvider: audience),
      );
      await tester.pump();

      // The "đang xem" caption changes based on enabled.
      expect(find.text('Đang xem ở góc nhìn chuyên môn.'), findsOneWidget);
    });
  });
}
