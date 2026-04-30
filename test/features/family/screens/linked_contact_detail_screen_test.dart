import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/screens/linked_contact_detail_screen.dart';
import 'package:healthguard/features/family/widgets/label_management_card.dart';
import 'package:healthguard/features/family/widgets/unlink_action_card.dart';

import '../test_support/fake_family_repository.dart';

void main() {
  // The screen lays out a hero card + sharing banner + 3 permission cards
  // before the label management cards and the unlink action. Combined height
  // exceeds the default 600px test viewport, so the lazy `ListView` keeps the
  // bottom widgets out of the element tree until we scroll. The helper below
  // scrolls until the requested finder hits the screen so taps land reliably.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

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

      // Scroll the first LabelManagementCard ("Nhãn chính hiển thị") into view
      // before tapping; the card and the "Thay đổi" affordance live below the
      // viewport fold once the hero + permission stack is rendered. We pass
      // the bare typed finder to scrollUntilVisible because dragUntilVisible
      // calls evaluate() on its argument before any drag — chaining `.first`
      // would invoke Iterable.first on an empty list (lazy ListView has not
      // realised the card yet) and crash with `Bad state: No element`.
      await scrollTo(tester, find.byType(LabelManagementCard));
      await tester.tap(find.byType(LabelManagementCard).first);
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

      // Same story for the unlink action — it sits at the bottom of the list.
      await scrollTo(tester, find.byType(UnlinkActionCard));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy liên kết'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hủy liên kết'));
      await tester.pumpAndSettle();
      expect(repository.removedRelationshipIds, <int>[91]);
    },
  );

  testWidgets(
    'P-4: medical-info toggle reflects current value and writes correct key',
    (tester) async {
      // Pin the new permission row: the toggle must read the current
      // ``can_view_medical_info`` flag from ``permissions`` and write the
      // exact same key when flipped. A typo in either direction silently
      // breaks the patient's privacy contract, hence the explicit pin.
      final repository = FakeFamilyRepository(
        detailById: <String, LinkedContactModel>{
          '91': LinkedContactModel(
            id: '91',
            displayName: 'An Nguyen',
            email: 'an@example.com',
            primaryRelationshipLabel: 'Mẹ',
            tags: <ContactTag>[ContactTagsConfig.defaultTags.first],
            // Start without medical-info permission so flipping the
            // toggle issues an "enable" write.
            permissions: const <String>['can_view_vitals'],
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

      // Toggle lives below the fold once the hero + 3 prior toggles
      // render — scroll the title text into view before tapping it.
      final medicalToggleFinder = find.text('Cho phép xem hồ sơ y tế của tôi');
      await scrollTo(tester, medicalToggleFinder);
      expect(medicalToggleFinder, findsOneWidget);

      await tester.tap(medicalToggleFinder);
      await tester.pumpAndSettle();

      // The provider sends the optimistic update through the repository
      // with ``can_view_medical_info: true``. We assert on both the key
      // (typo guard) and the value (no inverted boolean).
      final lastUpdate = repository.updateCalls.last;
      expect(lastUpdate['relationshipId'], 91);
      expect(
        (lastUpdate['data'] as Map<String, dynamic>)['can_view_medical_info'],
        isTrue,
      );
    },
  );
}
