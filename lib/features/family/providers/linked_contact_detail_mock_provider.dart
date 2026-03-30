import 'package:flutter/foundation.dart';
import 'package:healthguard/features/family/models/contact_tag.dart';
import 'package:healthguard/features/family/models/linked_contact_model.dart';
import 'package:healthguard/features/family/providers/shared_family_mock_provider.dart';

class LinkedContactDetailMockProvider extends ChangeNotifier {
  String? _contactId;
  bool _isLoading = true;
  String? _error;

  LinkedContactDetailMockProvider() {
    SharedFamilyMockProvider().addListener(_onGlobalChange);
  }

  void _onGlobalChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    SharedFamilyMockProvider().removeListener(_onGlobalChange);
    super.dispose();
  }

  // Track saving state per permission key to show inline loading indicator
  

  bool _isUnlinking = false;
  bool _isUpdatingLabel = false;

  LinkedContactModel? get contact {
    if (_contactId == null) return null;
    return SharedFamilyMockProvider().getContactById(_contactId!);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUnlinking => _isUnlinking;
  bool get isUpdatingLabel => _isUpdatingLabel;

  
  void loadContact(String contactId) {
    _contactId = contactId;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> togglePermission(String key, bool value) async {
    final currentContact = contact;
    if (currentContact == null) return false;

    try {
      final newPermissions = List<String>.from(currentContact.permissions);
      if (value) {
        if (!newPermissions.contains(key)) newPermissions.add(key);
      } else {
        newPermissions.remove(key);
      }

      // No await, background update
      SharedFamilyMockProvider().updateContactPermissions(
        currentContact.id,
        newPermissions,
      ).catchError((e) {
        debugPrint('Toggle loi: ');
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTags(List<ContactTag> newTags) async {
    final currentContact = contact;
    if (currentContact == null) return false;

    _isUpdatingLabel = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 220));

    await SharedFamilyMockProvider().updateContactTags(currentContact.id, newTags);
    
    _isUpdatingLabel = false;
    return true;
  }

  Future<bool> updatePrimaryLabel(String newLabel) async {
    final currentContact = contact;
    if (currentContact == null) return false;

    _isUpdatingLabel = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 180));

    await SharedFamilyMockProvider().updateContactPrimaryLabel(currentContact.id, newLabel);
    
    _isUpdatingLabel = false;
    return true;
  }

  // Deprecated: dùng updateTags hoặc updatePrimaryLabel thay thế
  Future<bool> updateLabel(ContactRole newRole) async {
    final currentContact = contact;
    if (currentContact == null) return false;

    _isUpdatingLabel = true;
    notifyListeners();

    // Simulate network delay (220ms as per plan)
    await Future.delayed(const Duration(milliseconds: 220));

    await SharedFamilyMockProvider().updateContactRole(currentContact.id, newRole);
    
    _isUpdatingLabel = false;
    return true;
  }

  Future<bool> unlinkContact() async {
    final currentContact = contact;
    if (currentContact == null) return false;

    _isUnlinking = true;
    notifyListeners();

    // Simulate API CALL (180ms as per plan)
    await Future.delayed(const Duration(milliseconds: 180));

    await SharedFamilyMockProvider().unlinkContact(currentContact.id);
    
    _isUnlinking = false;
    return true;
  }
}

