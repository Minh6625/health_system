import 'package:flutter/material.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/family/models/access_profile.dart';
import 'package:healthguard/features/family/models/relationship.dart';
import 'package:healthguard/features/family/repositories/family_repository.dart';

class TargetProfileProvider extends ChangeNotifier {
  final FamilyRepository _repository = FamilyRepository();
  final ApiClient _apiClient = ApiClient();

  List<AccessProfile> _profiles = [];
  List<Relationship> _relationships = [];
  AccessProfile? _currentProfile;
  bool _isLoading = false;
  String? _errorMessage;

  List<AccessProfile> get profiles => _profiles;
  List<Relationship> get relationships => _relationships;
  AccessProfile? get currentProfile => _currentProfile;
  int? get targetProfileId => _apiClient.targetProfileId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearData() {
    _profiles = [];
    _relationships = [];
    _currentProfile = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchProfiles({bool background = false}) async {
    if (!background) {
      if (!_isLoading) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }
    }

    try {
      _profiles = await _repository.getAccessProfiles();
      _relationships = await _repository.getRelationships();

      if (_currentProfile != null) {
        final stillExists = _profiles.any((p) => p.id == _currentProfile!.id);
        if (!stillExists) {
          setTargetProfile(null);
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error fetching profiles/relationships: \${e}");
    } finally {
      if (!background) {
        _isLoading = false;
      }
      notifyListeners(); // Always notify new data
    }
  }

  void setTargetProfile(int? profileId) {
    _apiClient.targetProfileId = profileId;
    if (profileId == null) {
      _currentProfile = null;
    } else {
      _currentProfile = _profiles.firstWhere((p) => p.id == profileId);
    }
    notifyListeners();
  }

  void switchToProfile(AccessProfile profile) {
    setTargetProfile(profile.id);
  }

  Future<bool> requestAccess(String email, {bool background = false}) async {
    if (!background) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _repository.requestAccess(email);
      await fetchProfiles(background: background);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      if (!background) {
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> acceptRequest(
    int relationshipId, {
    bool background = false,
  }) async {
    // 1. Optimistic update
    final idx = _relationships.indexWhere((r) => r.id == relationshipId);
    if (idx != -1) {
      final r = _relationships[idx];
      _relationships[idx] = Relationship(
        id: r.id,
        patientId: r.patientId,
        patientName: r.patientName,
        patientEmail: r.patientEmail,
        caregiverId: r.caregiverId,
        caregiverName: r.caregiverName,
        caregiverEmail: r.caregiverEmail,
        relationshipType: r.relationshipType,
        status: 'accepted',
      );
    }

    // 2. Start Loading state if not background
    if (!background) {
      _isLoading = true;
      _errorMessage = null;
    }
    notifyListeners();

    try {
      // 3. API request
      await _repository.acceptRequest(relationshipId);
      
      // 4. We can safely remove artificial delay because we have Optimistic update, 
      // but let's delay minimally just to ensure backend commits fully before next fetch
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 5. Fetch updated data. Ensure we pass the background flag correctly.
      await fetchProfiles(background: background);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      if (!background) {
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> removeRelationship(
    int relationshipId, {
    bool background = false,
  }) async {
    if (!background) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _repository.deleteRelationship(relationshipId);
      await fetchProfiles(background: background);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      if (!background) {
        _isLoading = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<List<dynamic>> searchUsers(String query) async {
    return _repository.searchUsers(query);
  }
}




