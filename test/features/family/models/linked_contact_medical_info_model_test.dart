import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/linked_contact_medical_info_model.dart';

void main() {
  group('LinkedContactMedicalInfoModel.fromJson', () {
    test('parses full payload with all fields populated', () {
      final json = <String, dynamic>{
        'contact_id': 77,
        'display_name': 'Bà Mẹ',
        'blood_type': 'O+',
        'height_cm': 158,
        'weight_kg': 52.5,
        'medications': <String>['Metformin 500mg', 'Losartan 50mg'],
        'allergies': <String>['Penicillin'],
        'medical_conditions': <String>['hypertension', 'diabetes'],
      };

      final model = LinkedContactMedicalInfoModel.fromJson(json);

      expect(model.contactId, 77);
      expect(model.displayName, 'Bà Mẹ');
      expect(model.bloodType, 'O+');
      expect(model.heightCm, 158);
      expect(model.weightKg, 52.5);
      expect(model.medications, <String>['Metformin 500mg', 'Losartan 50mg']);
      expect(model.allergies, <String>['Penicillin']);
      expect(model.medicalConditions, <String>['hypertension', 'diabetes']);
      expect(model.isEmpty, isFalse);
    });

    test('coerces num height/weight to int/double respectively', () {
      // Backend may surface ``height_cm`` as a JSON int or — in degraded
      // legacy rows — a JSON double. Either should land as int on the
      // model so the UI's ``${heightCm} cm`` formatter never prints
      // ``158.0 cm``.
      final json = <String, dynamic>{
        'contact_id': 1,
        'display_name': 'X',
        'height_cm': 158.0,
        'weight_kg': 52, // int → must coerce to double for kg display.
        'medications': const <String>[],
        'allergies': const <String>[],
        'medical_conditions': const <String>[],
      };

      final model = LinkedContactMedicalInfoModel.fromJson(json);

      expect(model.heightCm, 158);
      expect(model.weightKg, 52.0);
    });

    test(
      'falls back to defaults when optional fields are missing or null',
      () {
        // Backend sends ``null`` for unset optional scalars and may omit
        // list keys entirely on legacy rows. Both cases must produce a
        // non-empty model that the UI can render without null checks.
        final json = <String, dynamic>{
          'contact_id': 5,
          'display_name': 'Người dùng',
          'blood_type': null,
          'height_cm': null,
          'weight_kg': null,
        };

        final model = LinkedContactMedicalInfoModel.fromJson(json);

        expect(model.bloodType, isNull);
        expect(model.heightCm, isNull);
        expect(model.weightKg, isNull);
        expect(model.medications, isEmpty);
        expect(model.allergies, isEmpty);
        expect(model.medicalConditions, isEmpty);
        expect(model.isEmpty, isTrue);
      },
    );

    test('coerces non-list medication payload to empty list defensively', () {
      // Future contract drift: if the backend ever returns a string for
      // ``medications`` we shouldn't crash deserialisation — we drop to
      // an empty list and rely on the UI's empty state.
      final json = <String, dynamic>{
        'contact_id': 1,
        'display_name': 'X',
        'medications': 'not a list',
        'allergies': null,
        'medical_conditions': const <String>[],
      };

      final model = LinkedContactMedicalInfoModel.fromJson(json);

      expect(model.medications, isEmpty);
      expect(model.allergies, isEmpty);
    });

    test('isEmpty returns false when only one field is populated', () {
      // Sanity check: ``isEmpty`` must be conservative — only true when
      // every field is missing. A patient who filled just blood type
      // should still see a populated screen, not the "chưa cập nhật"
      // empty state.
      final model = LinkedContactMedicalInfoModel.fromJson(<String, dynamic>{
        'contact_id': 1,
        'display_name': 'X',
        'blood_type': 'A+',
      });

      expect(model.isEmpty, isFalse);
    });
  });
}
