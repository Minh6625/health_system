import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/models/family_profile_snapshot.dart';

import 'package:healthguard/features/family/repositories/family_repository.dart';

class SharedFamilyMockProvider extends ChangeNotifier {
  // Singleton instance
  static final SharedFamilyMockProvider _instance =
      SharedFamilyMockProvider._internal();
  factory SharedFamilyMockProvider() => _instance;
  SharedFamilyMockProvider._internal();

  final FamilyRepository _repository = FamilyRepository();

  bool _isLoading = false;
  String? _error;

  List<LinkedContactModel> _contacts = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LinkedContactModel> get contacts => _contacts;

  List<LinkedContactModel> get pendingRequests =>
      _contacts.where((c) => c.status == ContactStatus.pending).toList();

  List<LinkedContactModel> get acceptedContacts =>
      _contacts.where((c) => c.status == ContactStatus.accepted).toList();

  Future<void> loadInitialData(int currentUserId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final relationships = await _repository.getRelationships();

      _contacts = relationships.map((rel) {
        bool isIncoming = rel['patient_id'] == currentUserId;
        String displayName = isIncoming
            ? rel['caregiver_name']
            : rel['patient_name'];
        String email = isIncoming
            ? rel['caregiver_email']
            : rel['patient_email'];
        String? relationshipType = rel['relationship_type'];

        ContactRole role = ContactRole.unclassified;
        if (relationshipType == 'family') role = ContactRole.family;
        if (relationshipType == 'doctor') role = ContactRole.doctor;

        List<String> perms = [];
        if (rel['can_view_vitals'] == true) perms.add('can_view_vitals');
        if (rel['can_receive_alerts'] == true) perms.add('can_receive_alerts');
        if (rel['can_view_location'] == true) perms.add('can_view_location');
        if (rel['has_view_vitals_permission'] == true)
          perms.add('has_view_vitals_permission');

        // Parse tags from API
        List<ContactTag> parsedTags = [];
        if (rel['tags'] != null && rel['tags'] is List) {
          for (var tagMap in rel['tags']) {
            if (tagMap is Map<String, dynamic> && tagMap.containsKey('id')) {
              final matchedTag = ContactTagsConfig.findById(
                tagMap['id'].toString(),
              );
              if (matchedTag != null) {
                parsedTags.add(matchedTag);
              } else {
                parsedTags.add(
                  ContactTag(
                    id: tagMap['id'].toString(),
                    name: tagMap['name']?.toString() ?? 'Unknown',
                    color: const Color(0xFF9E9E9E),
                  ),
                );
              }
            }
          }
        }

        // Fallback for mock/empty data
        if (parsedTags.isEmpty && role == ContactRole.family) {
          parsedTags = [ContactTagsConfig.defaultTags[0]];
        }

        String primaryLabel =
            rel['primary_relationship_label'] ??
            (relationshipType == 'family' ? 'Gia đình' : 'Chưa phân loại');

        return LinkedContactModel(
          id: rel['id'].toString(),
          displayName: displayName,
          email: email,
          role: role,
          tags: parsedTags,
          primaryRelationshipLabel: primaryLabel,
          status: rel['status'] == 'pending'
              ? ContactStatus.pending
              : ContactStatus.accepted,
          isIncomingRequest: isIncoming,
          permissions: perms,
        );
      }).toList();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '').trim();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Phase 3: Accept Pending
  Future<void> acceptRequest(String contactId, List<String> permissions) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.acceptRelationship(int.parse(contactId));

      final index = _contacts.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _contacts[index] = _contacts[index].copyWith(
          status: ContactStatus.accepted,
          permissions: permissions,
        );
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> rejectRequest(String contactId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.removeRelationshipById(int.parse(contactId));
      _contacts.removeWhere((c) => c.id == contactId);
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Phase 4: Add Contact — nhận tags thay vì role cứng
  Future<void> sendRequest(String email, List<ContactTag> tags) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tagsData = tags.map((t) => {'id': t.id, 'name': t.name}).toList();
      final primaryLabel = tags.isNotEmpty ? tags.first.name : 'Chưa phân loại';

      await _repository.sendConnectionRequest(
        email: email,
        tags: tagsData,
        primaryLabel: primaryLabel,
      );

      // Cần load lại danh sách từ server thay vì add tay để có ID thật
      // tạm fake lại một đối tượng để UI phản hồi nhanh
      _contacts.add(
        LinkedContactModel(
          id: 'req_${DateTime.now().millisecondsSinceEpoch}',
          displayName: email.split('@').first,
          email: email,
          tags: tags,
          primaryRelationshipLabel: primaryLabel,
          role: ContactRole.unclassified,
          status: ContactStatus.pending,
          isIncomingRequest: false, // Outgoing
        ),
      );
    } catch (e) {
      debugPrint('Error sending request: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Phase 5: Detail updates
  Future<void> updateContactPermissions(
    String contactId,
    List<String> newPermissions,
  ) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index == -1) return;

    // Optimistic Update: prevent race conditions when tapping toggles quickly
    final oldContact = _contacts[index];
    _contacts[index] = oldContact.copyWith(permissions: newPermissions);
    notifyListeners();

    try {
      await _repository.updateRelationship(int.parse(contactId), {
        'can_view_vitals': newPermissions.contains('can_view_vitals'),
        'can_receive_alerts': newPermissions.contains('can_receive_alerts'),
        'can_view_location': newPermissions.contains('can_view_location'),
      });
    } catch (e) {
      debugPrint('Error updating permissions: $e');
      // Rollback
      final rollbackIndex = _contacts.indexWhere((c) => c.id == contactId);
      if (rollbackIndex != -1) {
        _contacts[rollbackIndex] = oldContact;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> updateContactTags(
    String contactId,
    List<ContactTag> newTags,
  ) async {
    try {
      final tagsData = newTags
          .map((t) => {'id': t.id, 'name': t.name})
          .toList();
      String? newPrimaryLabel = newTags.isNotEmpty ? newTags.first.name : null;

      await _repository.updateRelationship(int.parse(contactId), {
        'tags': tagsData,
        'primary_relationship_label': newPrimaryLabel,
      });

      final index = _contacts.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _contacts[index] = _contacts[index].copyWith(
          tags: newTags,
          // Cập nhật luôn primary label nếu tags thay đổi và có ít nhất 1 tag
          primaryRelationshipLabel: newPrimaryLabel,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating tags: $e');
      rethrow;
    }
  }

  Future<void> updateContactPrimaryLabel(
    String contactId,
    String newLabel,
  ) async {
    try {
      await _repository.updateRelationship(int.parse(contactId), {
        'primary_relationship_label': newLabel,
      });

      final index = _contacts.indexWhere((c) => c.id == contactId);
      if (index != -1) {
        _contacts[index] = _contacts[index].copyWith(
          primaryRelationshipLabel: newLabel,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating primary label: $e');
      rethrow;
    }
  }

  Future<void> updateContactRole(String contactId, ContactRole newRole) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index != -1) {
      _contacts[index] = _contacts[index].copyWith(role: newRole);
      notifyListeners();
    }
  }

  Future<void> unlinkContact(String contactId) async {
    try {
      await _repository.removeRelationshipById(int.parse(contactId));
      _contacts.removeWhere((c) => c.id == contactId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error unlinking contact: $e');
      rethrow;
    }
  }

  LinkedContactModel? getContactById(String id) {
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Phase 6: Sync to FamilyDashboard
  List<FamilyProfileSnapshot> generateDashboardSnapshots() {
    return acceptedContacts.map((c) {
      // Mock vital variety dựa theo id
      bool isSos = c.id == '2'; // Mock 'Mẹ' có SOS
      String risk = c.id == '3' ? 'high' : 'low';
      if (c.id == '1') risk = 'medium';
      bool pinned = c.id == '1' || c.id == '3'; // Bố và Bác sĩ là ưu tiên

      // Mock BP: Mẹ tăng nhẹ, Bác sĩ cao, còn lại bình thường
      int? sys, dia;
      if (c.id == '2') {
        sys = 138;
        dia = 88;
      } else if (c.id == '3') {
        sys = 145;
        dia = 92;
      } else {
        sys = 118;
        dia = 76;
      }

      // Mock Temp: Mẹ sốt nhẹ, còn lại bình thường
      double temp = c.id == '2' ? 37.8 : 36.5 + (c.id.hashCode % 3) * 0.1;

      // Mock sleep data
      int sleepMin;
      String sleepQual;
      if (c.id == '1') {
        sleepMin = 480;
        sleepQual = 'Tốt';
      } else if (c.id == '2') {
        sleepMin = 330;
        sleepQual = 'Kém';
      } else {
        sleepMin = 420;
        sleepQual = 'Trung bình';
      }

      // Mock health score 7 ngày
      int score;
      String scoreLevel;
      if (c.id == '1') {
        score = 72;
        scoreLevel = 'Trung bình';
      } else if (c.id == '2') {
        score = 48;
        scoreLevel = 'Thấp';
      } else {
        score = 85;
        scoreLevel = 'Cao';
      }

      return FamilyProfileSnapshot(
        id: c.id,
        name: c.displayName.split(' - ').last,
        relation: c.primaryRelationshipLabel.isNotEmpty
            ? c.primaryRelationshipLabel
            : c.role.label,
        heartRate: 70 + (c.id.hashCode % 30),
        spo2: 95 + (c.id.hashCode % 5),
        bloodPressureSystolic: sys,
        bloodPressureDiastolic: dia,
        bodyTemperature: temp,
        riskLevel: risk,
        isSosActive: isSos,
        sosId: isSos ? 'sos-mock-${c.id}-001' : null,
        isPinned: pinned,
        hasViewVitalsPermission: c.permissions.contains(
          'has_view_vitals_permission',
        ),
        lastUpdated: DateTime.now().subtract(
          Duration(minutes: c.hashCode.abs() % 10),
        ),
        specialNote: isSos
            ? 'Cần hỗ trợ ngay!'
            : (risk == 'medium' ? 'Huyết áp cần theo dõi' : ''),
        sleepDurationMinutes: sleepMin,
        sleepQuality: sleepQual,
        healthScore7Days: score,
        healthScoreLevel: scoreLevel,
      );
    }).toList();
  }
}
