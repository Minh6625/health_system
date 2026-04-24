import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/family/models/access_profile_model.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/providers/family_relationship_provider.dart';

import '../test_support/fake_family_repository.dart';

void main() {
  test(
    'load derives pending accepted and caregiver SOS access from backend',
    () async {
      final repository = FakeFamilyRepository(
        relationships: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 91,
            'patient_id': 12,
            'patient_name': 'An Nguyen',
            'patient_email': 'an@example.com',
            'caregiver_id': 7,
            'caregiver_name': 'Caregiver',
            'caregiver_email': 'caregiver@example.com',
            'relationship_type': 'family',
            'status': 'pending',
            'primary_relationship_label': 'Mẹ',
            'tags': <Map<String, dynamic>>[
              <String, dynamic>{'id': 'family', 'name': 'Gia đình'},
            ],
            'can_view_vitals': false,
            'can_receive_alerts': false,
            'can_view_location': false,
            'has_view_vitals_permission': false,
          },
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
            'can_receive_alerts': true,
            'can_view_location': true,
            'has_view_vitals_permission': false,
          },
        ],
        accessProfiles: <AccessProfileModel>[
          const AccessProfileModel(
            id: 7,
            fullName: 'Caregiver',
            relationshipType: 'self',
            canViewVitals: true,
            canReceiveAlerts: true,
            canViewLocation: true,
          ),
          const AccessProfileModel(
            id: 15,
            fullName: 'Binh Tran',
            relationshipType: 'family',
            canViewVitals: true,
            canReceiveAlerts: true,
            canViewLocation: true,
          ),
        ],
      );

      final provider = FamilyRelationshipProvider(repository: repository);

      await provider.load(7);

      expect(provider.pendingRequests, hasLength(1));
      expect(provider.pendingRequests.single.displayName, 'An Nguyen');
      expect(provider.acceptedContacts, hasLength(1));
      expect(
        provider.acceptedContacts.single.permissions,
        containsAll(<String>[
          'can_view_vitals',
          'can_receive_alerts',
          'can_view_location',
        ]),
      );
      expect(provider.canReceiveAlerts, isTrue);
    },
  );

  test('acceptRequest orchestrates accept then update then reload', () async {
    final repository = FakeFamilyRepository(
      relationships: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 91,
          'patient_id': 12,
          'patient_name': 'An Nguyen',
          'patient_email': 'an@example.com',
          'caregiver_id': 7,
          'caregiver_name': 'Caregiver',
          'caregiver_email': 'caregiver@example.com',
          'relationship_type': 'family',
          'status': 'pending',
          'primary_relationship_label': 'Mẹ',
          'tags': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'family', 'name': 'Gia đình'},
          ],
          'can_view_vitals': false,
          'can_receive_alerts': false,
          'can_view_location': false,
          'has_view_vitals_permission': false,
        },
      ],
      accessProfiles: <AccessProfileModel>[
        const AccessProfileModel(
          id: 7,
          fullName: 'Caregiver',
          relationshipType: 'self',
          canViewVitals: true,
          canReceiveAlerts: true,
          canViewLocation: true,
        ),
      ],
    );

    final provider = FamilyRelationshipProvider(repository: repository);
    await provider.load(7);

    await provider.acceptRequest(
      request: provider.pendingRequests.single,
      permissions: const <String>[
        'can_view_vitals',
        'can_receive_alerts',
      ],
      tags: <ContactTag>[ContactTagsConfig.defaultTags.first],
      primaryLabel: 'Mẹ',
    );

    expect(repository.acceptedRelationshipIds, <int>[91]);
    expect(repository.updateCalls.single['relationshipId'], 91);
    expect(
      (repository.updateCalls.single['data'] as Map<String, dynamic>)[
        'can_view_vitals'
      ],
      isTrue,
    );
  });
}
