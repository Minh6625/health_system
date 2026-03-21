import 'package:healthguard/features/family/models/linked_contact_model.dart';

enum ContactMockScenario {
  successWithPending,
  successNoPending,
  empty,
  error,
  offlineCache,
}

class ContactMockConfig {
  static bool useMockData = true;
  static ContactMockScenario scenario = ContactMockScenario.successWithPending;
}

class ContactMockSnapshots {
  static final List<LinkedContactModel> initialContacts = [
    LinkedContactModel(
      id: 'c1',
      displayName: 'Nguyễn Văn C',
      email: 'nvc@email.com',
      status: ContactStatus.pending,
      isIncomingRequest: true,
    ),
    LinkedContactModel(
      id: 'c5',
      displayName: 'Trần Thị D',
      email: 'ttd@email.com',
      status: ContactStatus.pending,
      isIncomingRequest: true,
    ),
    LinkedContactModel(
      id: 'c2',
      displayName: 'Bố - Nguyễn Văn A',
      email: 'bova@email.com',
      role: ContactRole.family,
      status: ContactStatus.accepted,
      permissions: ['receive_alerts', 'view_vitals'],
    ),
    LinkedContactModel(
      id: 'c3',
      displayName: 'BS Trần B',
      email: 'bstb@email.com',
      role: ContactRole.doctor,
      status: ContactStatus.accepted,
      permissions: ['receive_alerts'],
    ),
    LinkedContactModel(
      id: 'c4',
      displayName: 'Bạn Mai',
      email: 'maimai@email.com',
      role: ContactRole.unclassified,
      status: ContactStatus.accepted,
      permissions: [],
    ),
  ];
}
