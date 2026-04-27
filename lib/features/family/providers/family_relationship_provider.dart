import 'package:flutter/material.dart';
import 'package:healthguard/features/family/models/access_profile_model.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/models/user_search_model.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';

class FamilyRelationshipProvider extends ChangeNotifier {
  FamilyRelationshipProvider({FamilyRepository? repository})
    : _repository = repository ?? FamilyRepository();

  final FamilyRepository _repository;

  bool _isLoading = false;
  bool _isMutating = false;
  String? _error;
  int? _loadedUserId;
  List<Map<String, dynamic>> _relationships = const <Map<String, dynamic>>[];
  List<AccessProfileModel> _accessProfiles = const <AccessProfileModel>[];

  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;

  List<LinkedContactModel> get contacts =>
      _relationships.map(_toContact).toList(growable: false);

  List<LinkedContactModel> get pendingRequests => contacts
      .where((contact) => contact.status == ContactStatus.pending)
      .toList(growable: false);

  List<LinkedContactModel> get acceptedContacts => contacts
      .where((contact) => contact.status == ContactStatus.accepted)
      .toList(growable: false);

  bool get canReceiveAlerts => _accessProfiles.any(
    (profile) => profile.relationshipType != 'self' && profile.canReceiveAlerts,
  );

  Future<void> load(int currentUserId, {bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    _loadedUserId = currentUserId;
    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _repository.getRelationships(),
        _repository.getAccessProfiles(),
      ]);
      _relationships = List<Map<String, dynamic>>.from(results[0] as List);
      _accessProfiles = List<AccessProfileModel>.from(results[1] as List);
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '').trim();
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadInitialData(int currentUserId, {bool silent = false}) async {
    await load(currentUserId, silent: silent);
  }

  Future<void> reload({bool silent = true}) async {
    final userId = _loadedUserId;
    if (userId == null) {
      return;
    }
    await load(userId, silent: silent);
  }

  Future<void> sendRequestToUser({
    required UserSearchModel user,
    required List<ContactTag> tags,
    required String primaryLabel,
  }) async {
    final tagsData = tags
        .map((tag) => <String, dynamic>{'id': tag.id, 'name': tag.name})
        .toList(growable: false);

    await _runMutation(() async {
      await _repository.sendConnectionRequest(
        targetUserId: user.id > 0 ? user.id : null,
        email: user.id > 0 ? null : user.email,
        tags: tagsData,
        primaryLabel: primaryLabel,
      );
      await reload();
    });
  }

  Future<void> sendRequest(String email, List<ContactTag> tags) async {
    final tagsData = tags
        .map((tag) => <String, dynamic>{'id': tag.id, 'name': tag.name})
        .toList(growable: false);

    await _runMutation(() async {
      await _repository.sendConnectionRequest(
        email: email,
        tags: tagsData,
        primaryLabel: tags.isNotEmpty ? tags.first.name : 'Chưa phân loại',
      );
      await reload();
    });
  }

  Future<void> acceptRequest({
    required LinkedContactModel request,
    required List<String> permissions,
    List<ContactTag>? tags,
    String? primaryLabel,
  }) async {
    final relationshipId = int.parse(request.id);
    final payload = <String, dynamic>{
      'can_view_vitals': permissions.contains('can_view_vitals'),
      'can_receive_alerts': permissions.contains('can_receive_alerts'),
      'can_view_location': permissions.contains('can_view_location'),
      if (tags != null)
        'tags': tags
            .map((tag) => <String, dynamic>{'id': tag.id, 'name': tag.name})
            .toList(growable: false),
      'primary_relationship_label': ?primaryLabel,
    };

    await _runMutation(() async {
      await _repository.acceptRelationship(relationshipId);
      await _repository.updateRelationship(relationshipId, payload);
      await reload();
    });
  }

  Future<void> rejectRequest(LinkedContactModel request) async {
    await _runMutation(() async {
      await _repository.removeRelationshipById(int.parse(request.id));
      await reload();
    });
  }

  Future<void> cancelRequest(UserSearchModel user) async {
    await _runMutation(() async {
      await _repository.cancelConnectionRequest(user.id);
      await reload();
    });
  }

  Future<void> unlinkByRelationshipId(int relationshipId) async {
    await _runMutation(() async {
      await _repository.removeRelationshipById(relationshipId);
      await reload();
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    _isMutating = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '').trim();
      rethrow;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  LinkedContactModel _toContact(Map<String, dynamic> rel) {
    final currentUserId = _loadedUserId;
    final isIncoming =
        currentUserId != null && rel['patient_id'] == currentUserId;
    final displayName =
        isIncoming ? rel['caregiver_name'] : rel['patient_name'];
    final email = isIncoming ? rel['caregiver_email'] : rel['patient_email'];
    final relationshipType = rel['relationship_type'] as String?;

    var role = ContactRole.unclassified;
    if (relationshipType == 'family') {
      role = ContactRole.family;
    } else if (relationshipType == 'doctor') {
      role = ContactRole.doctor;
    } else if (relationshipType == 'friend') {
      role = ContactRole.friend;
    }

    final permissions = <String>[];
    if (rel['can_view_vitals'] == true) {
      permissions.add('can_view_vitals');
    }
    if (rel['can_receive_alerts'] == true) {
      permissions.add('can_receive_alerts');
    }
    if (rel['can_view_location'] == true) {
      permissions.add('can_view_location');
    }
    if (rel['has_view_vitals_permission'] == true) {
      permissions.add('has_view_vitals_permission');
    }

    final tags = (rel['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) {
          if (entry is Map) {
            final normalizedEntry = Map<String, dynamic>.from(entry);
            final id = normalizedEntry['id'].toString();
            final fallback = ContactTagsConfig.findById(id);
            return ContactTag(
              id: id,
              name: normalizedEntry['name']?.toString() ?? id,
              color: fallback?.color ?? const Color(0xFF5B7288),
            );
          }
          final id = entry.toString();
          final fallback = ContactTagsConfig.findById(id);
          return ContactTag(
            id: id,
            name: id,
            color: fallback?.color ?? const Color(0xFF5B7288),
          );
        })
        .toList(growable: false);

    return LinkedContactModel(
      id: rel['id'].toString(),
      displayName: displayName as String? ?? 'N/A',
      email: email as String? ?? '',
      role: role,
      tags: tags,
      primaryRelationshipLabel:
          rel['primary_relationship_label'] as String? ??
          (tags.isNotEmpty ? tags.first.name : 'Chưa gắn tag'),
      status:
          rel['status'] == 'pending'
              ? ContactStatus.pending
              : ContactStatus.accepted,
      permissions: permissions,
      isIncomingRequest: isIncoming,
    );
  }
}
