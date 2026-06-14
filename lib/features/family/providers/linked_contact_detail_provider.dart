import 'package:flutter/foundation.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';

const List<String> _kAllPermissionKeys = [
  'can_view_vitals',
  'can_receive_alerts',
  'can_view_location',
  'can_view_medical_info',
];

class LinkedContactDetailProvider extends ChangeNotifier {
  LinkedContactDetailProvider({FamilyRepository? repository})
    : _repository = repository ?? FamilyRepository();

  final FamilyRepository _repository;
  LinkedContactModel? _contact;
  bool _isLoading = true;
  String? _error;

  // Draft permission list — edited locally, only persisted on savePermissions().
  List<String>? _draftPermissions;
  bool _isSavingPermissions = false;
  String? _savePermissionsError;

  bool _isUnlinking = false;
  bool _isUpdatingLabel = false;

  LinkedContactModel? get contact => _contact;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Current draft permissions the user is editing. Falls back to the
  /// server-side list when no draft has been initialised yet.
  List<String> get draftPermissions =>
      _draftPermissions ?? _contact?.permissions ?? const [];

  /// True when the draft differs from the last saved state.
  bool get hasUnsavedChanges {
    final saved = _contact?.permissions ?? const [];
    final draft = _draftPermissions ?? saved;
    if (draft.length != saved.length) return true;
    return draft.any((p) => !saved.contains(p)) ||
        saved.any((p) => !draft.contains(p));
  }

  bool get isSavingPermissions => _isSavingPermissions;
  String? get savePermissionsError => _savePermissionsError;

  bool get isUnlinking => _isUnlinking;
  bool get isUpdatingLabel => _isUpdatingLabel;

  Future<void> loadContact(String contactId) async {
    _isLoading = true;
    _error = null;
    // Reset draft so the fresh server state is picked up on load.
    _draftPermissions = null;
    _savePermissionsError = null;
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
      // Seed draft from server state so toggles start at the persisted values.
      _draftPermissions = List<String>.from(_contact!.permissions);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update a single permission in the LOCAL draft only — no network call.
  /// Call [savePermissions] to persist all changes at once.
  void updateDraftPermission(String key, bool value) {
    final current = List<String>.from(
      _draftPermissions ?? _contact?.permissions ?? [],
    );
    if (value) {
      if (!current.contains(key)) current.add(key);
    } else {
      current.remove(key);
    }
    _draftPermissions = current;
    _savePermissionsError = null;
    notifyListeners();
  }

  /// Persist all draft permissions to the backend in a single PUT call.
  Future<bool> savePermissions() async {
    if (_contact == null) return false;
    _isSavingPermissions = true;
    _savePermissionsError = null;
    notifyListeners();

    final draft = _draftPermissions ?? _contact!.permissions;
    final payload = <String, dynamic>{
      for (final key in _kAllPermissionKeys) key: draft.contains(key),
    };

    try {
      await _repository.updateRelationship(int.parse(_contact!.id), payload);
      // Commit draft → saved state.
      _contact = _contact!.copyWith(permissions: List<String>.from(draft));
      _isSavingPermissions = false;
      notifyListeners();
      return true;
    } catch (e) {
      _savePermissionsError = e.toString();
      _isSavingPermissions = false;
      notifyListeners();
      return false;
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
