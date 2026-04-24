import 'package:flutter/foundation.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';

class LinkedContactDetailProvider extends ChangeNotifier {
  LinkedContactDetailProvider({FamilyRepository? repository})
    : _repository = repository ?? FamilyRepository();

  final FamilyRepository _repository;
  LinkedContactModel? _contact;
  bool _isLoading = true;
  String? _error;

  LinkedContactModel? get contact => _contact;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _isUnlinking = false;
  bool _isUpdatingLabel = false;

  bool get isUnlinking => _isUnlinking;
  bool get isUpdatingLabel => _isUpdatingLabel;

  Future<void> loadContact(String contactId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (int.tryParse(contactId) == null) {
      _contact = null;
      _error = 'ID liên hệ không hợp lệ.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _contact = await _repository.getLinkedContactDetail(contactId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> unlinkContact() async {
    if (_contact == null) return false;
    _isUnlinking = true;
    notifyListeners();
    try {
      await _repository.removeRelationshipById(int.parse(_contact!.id));
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUnlinking = false;
      notifyListeners();
    }
  }

  Future<bool> updatePrimaryLabel(String newLabel) async {
    if (_contact == null) return false;
    _isUpdatingLabel = true;
    notifyListeners();
    try {
      await _repository.updateRelationship(int.parse(_contact!.id), {
        'primary_relationship_label': newLabel,
      });
      _contact = _contact!.copyWith(primaryRelationshipLabel: newLabel);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isUpdatingLabel = false;
      notifyListeners();
    }
  }

  Future<bool> togglePermission(String key, bool value) async {
    if (_contact == null) return false;

    // Optimistic UI Update
    var oldPermissions = List<String>.from(_contact!.permissions);
    var newPermissions = List<String>.from(_contact!.permissions);
    if (value) {
      if (!newPermissions.contains(key)) newPermissions.add(key);
    } else {
      newPermissions.remove(key);
    }
    _contact = _contact!.copyWith(permissions: newPermissions);
    notifyListeners();

    try {
      await _repository.updateRelationship(int.parse(_contact!.id), {
        key: value,
      });
      return true;
    } catch (e) {
      _error = e.toString();
      // Revert Optimistic UI Update
      _contact = _contact!.copyWith(permissions: oldPermissions);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTags(List<ContactTag> newTags) async {
    if (_contact == null) return false;
    try {
      final tagsData = newTags
          .map((t) => {'id': t.id, 'name': t.name})
          .toList();
      await _repository.updateRelationship(int.parse(_contact!.id), {
        'tags': tagsData,
      });
      _contact = _contact!.copyWith(tags: newTags);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
