import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/access_profile_model.dart';
import 'package:healthguard/features/family/models/user_search_model.dart';
import 'package:healthguard/features/family/providers/family_relationship_provider.dart';
import 'package:healthguard/features/family/screens/add_contact_screen.dart';
import 'package:healthguard/features/family/widgets/mode_segmented_control.dart';
import 'package:provider/provider.dart';

import '../test_support/fake_family_repository.dart';

void main() {
  testWidgets(
    'search flow sends request with real user id and no synthetic fallback',
    (tester) async {
      final repository = FakeFamilyRepository(
        accessProfiles: const <AccessProfileModel>[],
        searchResultsByQuery: <String, List<UserSearchModel>>{
          '0909': <UserSearchModel>[
            UserSearchModel(
              id: 77,
              fullName: 'Target User',
              email: 'target@example.com',
              phone: '0909',
            ),
          ],
        },
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => FamilyRelationshipProvider(repository: repository),
          child: MaterialApp(
            home: AddContactScreen(
              repository: repository,
              initialMode: AddContactMode.searchPhone,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('family-search-field')),
        '0909',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('family-search-result-77')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('family-search-action-77')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('family-confirm-submit')));
      await tester.pumpAndSettle();

      expect(repository.requestCalls, hasLength(1));
      expect(repository.requestCalls.single['targetUserId'], 77);
      expect(repository.requestCalls.single['email'], isNull);
    },
  );
}
