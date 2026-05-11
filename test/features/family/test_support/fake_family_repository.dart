import 'package:healthguard/features/family/models/access_profile_model.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';
import 'package:healthguard/features/family/models/linked_contact_medical_info_model.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/models/user_search_model.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';

class FakeFamilyRepository extends FamilyRepository {
  FakeFamilyRepository({
    this.relationships = const [],
    this.accessProfiles = const [],
    this.dashboard = const [],
    this.detailById = const {},
    this.searchResultsByQuery = const {},
    this.medicalInfoById = const {},
    this.medicalInfoErrorById = const {},
  });

  List<Map<String, dynamic>> relationships;
  List<AccessProfileModel> accessProfiles;
  List<FamilyProfileSnapshot> dashboard;
  Map<String, LinkedContactModel> detailById;
  Map<String, List<UserSearchModel>> searchResultsByQuery;

  /// Successful payloads keyed by ``contactId``. Lookup wins over
  /// ``medicalInfoErrorById`` so a fixture can override an error to a
  /// success without rebuilding the whole map.
  Map<String, LinkedContactMedicalInfoModel> medicalInfoById;

  /// Pre-baked exceptions to throw for a given ``contactId``. Use to drive
  /// the 403 / 404 / generic-error branches of the screen under test.
  Map<String, Exception> medicalInfoErrorById;

  final List<String> medicalInfoFetchedIds = <String>[];

  final List<Map<String, dynamic>> updateCalls = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> requestCalls = <Map<String, dynamic>>[];
  final List<int> acceptedRelationshipIds = <int>[];
  final List<int> cancelledTargetUserIds = <int>[];
  final List<int> removedRelationshipIds = <int>[];

  @override
  Future<List<Map<String, dynamic>>> getRelationships() async => relationships;

  @override
  Future<List<AccessProfileModel>> getAccessProfiles() async => accessProfiles;

  @override
  Future<List<FamilyProfileSnapshot>> getFamilyDashboard() async => dashboard;

  @override
  Future<LinkedContactModel> getLinkedContactDetail(String id) async =>
      detailById[id]!;

  @override
  Future<LinkedContactMedicalInfoModel> getLinkedContactMedicalInfo(
    String id,
  ) async {
    medicalInfoFetchedIds.add(id);
    final hit = medicalInfoById[id];
    if (hit != null) {
      return hit;
    }
    final err = medicalInfoErrorById[id];
    if (err != null) {
      throw err;
    }
    throw Exception('FakeFamilyRepository: no fixture for medical info $id');
  }

  @override
  Future<List<UserSearchModel>> searchUsers(String query) async {
    return searchResultsByQuery[query] ?? const <UserSearchModel>[];
  }

  @override
  Future<void> sendConnectionRequest({
    String? phone,
    String? email,
    int? targetUserId,
    String relationshipType = 'family',
    List<Map<String, dynamic>>? tags,
    String? primaryLabel,
  }) async {
    requestCalls.add(<String, dynamic>{
      'phone': phone,
      'email': email,
      'targetUserId': targetUserId,
      'relationshipType': relationshipType,
      'tags': tags,
      'primaryLabel': primaryLabel,
    });
  }

  @override
  Future<void> acceptRelationship(int relationshipId) async {
    acceptedRelationshipIds.add(relationshipId);
  }

  @override
  Future<void> updateRelationship(
    int relationshipId,
    Map<String, dynamic> data,
  ) async {
    updateCalls.add(<String, dynamic>{
      'relationshipId': relationshipId,
      'data': data,
    });
  }

  @override
  Future<void> removeRelationshipById(int relationshipId) async {
    removedRelationshipIds.add(relationshipId);
  }

  @override
  Future<void> cancelConnectionRequest(int targetUserId) async {
    cancelledTargetUserIds.add(targetUserId);
  }
}
