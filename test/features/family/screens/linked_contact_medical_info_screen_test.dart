import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:healthguard/features/family/models/linked_contact_medical_info_model.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';
import 'package:healthguard/features/family/screens/linked_contact_medical_info_screen.dart';

import '../test_support/fake_family_repository.dart';

void main() {
  // Helper that pumps the screen with the given fake and waits until any
  // pending fetches resolve. Each test resets state, so the helper rebuilds
  // a fresh widget tree per call.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeFamilyRepository repository,
    String contactId = '77',
    String? prefilledName,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LinkedContactMedicalInfoScreen(
          contactId: contactId,
          prefilledName: prefilledName,
          repositoryOverride: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders body fields when permission is granted',
    (tester) async {
      // Pin the happy path: each medical field surfaces in the rendered
      // tree exactly once. If the screen ever stops rendering one of
      // these (e.g. someone removes the medications section in a
      // refactor) this test fails loudly.
      final repository = FakeFamilyRepository(
        medicalInfoById: <String, LinkedContactMedicalInfoModel>{
          '77': const LinkedContactMedicalInfoModel(
            contactId: 77,
            displayName: 'Bà Mẹ',
            bloodType: 'O+',
            heightCm: 158,
            weightKg: 52.5,
            medications: <String>['Metformin 500mg', 'Losartan 50mg'],
            allergies: <String>['Penicillin'],
            medicalConditions: <String>['hypertension', 'diabetes'],
          ),
        },
      );

      await pumpScreen(
        tester,
        repository: repository,
        prefilledName: 'Bà Mẹ',
      );

      // App-bar shows the contact's name so the caregiver knows whose
      // medical info they are viewing — important when navigating back
      // from a deep stack.
      expect(find.textContaining('Bà Mẹ'), findsWidgets);

      // Body sections — labels always render; values come from the model.
      expect(find.text('Nhóm máu'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('158 cm'), findsOneWidget);
      // Weight is formatted via toStringAsFixed(1) so 52.5 stays "52.5"
      // rather than printing the trailing zero on integer-typed values.
      expect(find.text('52.5 kg'), findsOneWidget);

      // Medication chips render verbatim.
      expect(find.text('Metformin 500mg'), findsOneWidget);
      expect(find.text('Losartan 50mg'), findsOneWidget);

      // Allergy chip.
      expect(find.text('Penicillin'), findsOneWidget);

      // Medical conditions render via VN label map, NOT raw enum keys.
      // ``hypertension`` → "Cao huyết áp"; ``diabetes`` → "Tiểu đường".
      expect(find.text('Cao huyết áp'), findsOneWidget);
      expect(find.text('Tiểu đường'), findsOneWidget);

      // Privacy reminder banner is always visible on the ready state to
      // remind clinicians the data is patient-curated.
      expect(
        find.textContaining('Thông tin do người dùng tự khai báo'),
        findsOneWidget,
      );

      expect(repository.medicalInfoFetchedIds, <String>['77']);
    },
  );

  testWidgets(
    'shows permission-denied empty state when repository throws denied exception',
    (tester) async {
      // Pin the 403 UX: the screen must render the warning panel, NOT a
      // red error banner. Caregivers should be guided to ask the
      // patient to flip the toggle, not assume the app is broken.
      final repository = FakeFamilyRepository(
        medicalInfoErrorById: <String, Exception>{
          '77': const MedicalInfoPermissionDeniedException(
            'Người này chưa cho phép bạn xem hồ sơ y tế.',
          ),
        },
      );

      await pumpScreen(
        tester,
        repository: repository,
        prefilledName: 'Bà Mẹ',
      );

      expect(find.text('Chưa được chia sẻ hồ sơ y tế'), findsOneWidget);
      expect(
        find.textContaining('Bà Mẹ chưa cho phép bạn'),
        findsOneWidget,
      );
      // The hint instructs the caregiver where the toggle lives.
      expect(
        find.textContaining('Cho phép xem hồ sơ y tế của tôi'),
        findsOneWidget,
      );

      // No medical fields rendered — the empty state replaces them
      // wholesale, so no leak of stale data from a previous fetch.
      expect(find.text('Nhóm máu'), findsNothing);
    },
  );

  testWidgets(
    'shows generic empty state when contact link is gone',
    (tester) async {
      // 404 path: the link was unlinked between tap and load. Screen
      // should explain (not show "lỗi") and let the caregiver pull to
      // refresh in case the link came back.
      final repository = FakeFamilyRepository(
        medicalInfoErrorById: <String, Exception>{
          '77': const MedicalInfoNotFoundException(
            'Không tìm thấy dữ liệu liên hệ này',
          ),
        },
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('Không tìm thấy liên hệ'), findsOneWidget);
      expect(
        find.textContaining('liên kết đã bị huỷ'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows error state with retry button on generic failure',
    (tester) async {
      // Anything that isn't 403/404 (network, timeout, parse error) must
      // route to the red error UI so the caregiver knows something is
      // off and can retry.
      final repository = FakeFamilyRepository(
        medicalInfoErrorById: <String, Exception>{
          '77': Exception('Network error: connection refused'),
        },
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('Có lỗi khi tải hồ sơ y tế'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Thử lại'), findsOneWidget);
    },
  );

  testWidgets(
    'renders "chưa cập nhật" placeholders for missing optional fields',
    (tester) async {
      // Patients commonly fill some fields and skip others. The screen
      // must show the populated chips/values AND a "Chưa cập nhật"
      // placeholder for the empty ones — never an awkward blank row.
      final repository = FakeFamilyRepository(
        medicalInfoById: <String, LinkedContactMedicalInfoModel>{
          '77': const LinkedContactMedicalInfoModel(
            contactId: 77,
            displayName: 'X',
            bloodType: 'A+',
            // height/weight intentionally null
            medications: <String>[],
            allergies: <String>[],
            medicalConditions: <String>[],
          ),
        },
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('A+'), findsOneWidget);
      // Height + weight rows show the placeholder.
      expect(find.text('Chưa cập nhật'), findsNWidgets(2));
      // Medication / allergy / condition empty hints render once each.
      expect(find.text('Chưa khai báo thuốc đang dùng.'), findsOneWidget);
      expect(find.text('Chưa khai báo dị ứng.'), findsOneWidget);
      expect(find.text('Chưa khai báo tiền sử bệnh.'), findsOneWidget);
    },
  );

  testWidgets(
    'shows empty profile state when patient has not filled any fields',
    (tester) async {
      // Edge case where the patient granted permission but never opened
      // MedicalInfoScreen. We render a single "chưa cập nhật" panel
      // instead of stacking multiple empty cards.
      final repository = FakeFamilyRepository(
        medicalInfoById: <String, LinkedContactMedicalInfoModel>{
          '77': const LinkedContactMedicalInfoModel(
            contactId: 77,
            displayName: 'Người dùng',
          ),
        },
      );

      await pumpScreen(tester, repository: repository);

      expect(find.text('Chưa có hồ sơ y tế'), findsOneWidget);
      // The single combined empty state rules out per-section empties.
      expect(find.text('Chưa khai báo thuốc đang dùng.'), findsNothing);
    },
  );
}
