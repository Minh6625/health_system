import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/screens/linked_contact_detail_screen.dart';

import '../test_support/fake_family_repository.dart';

void main() {
  testWidgets(
    'detail screen updates permission label and unlinks through repository',
    (tester) async {
      final repository = FakeFamilyRepository(
        detailById: <String, LinkedContactModel>{
          '91': LinkedContactModel(
            id: '91',
            displayName: 'An Nguyen',
            email: 'an@example.com',
            primaryRelationshipLabel: 'Mẹ',
            tags: <ContactTag>[ContactTagsConfig.defaultTags.first],
            permissions: const <String>['can_receive_alerts'],
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LinkedContactDetailScreen(
            contactId: '91',
            repository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Cho phép xem chỉ số sức khoẻ của tôi'));
      await tester.pumpAndSettle();
      expect(
        (repository.updateCalls.last['data'] as Map<String, dynamic>)[
          'can_view_vitals'
        ],
        isTrue,
      );

      await tester.tap(find.text('Thay đổi').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Mẹ ruột');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(
        (repository.updateCalls.last['data'] as Map<String, dynamic>)[
          'primary_relationship_label'
        ],
        'Mẹ ruột',
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy liên kết'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hủy liên kết'));
      await tester.pumpAndSettle();
      expect(repository.removedRelationshipIds, <int>[91]);
    },
  );
}
