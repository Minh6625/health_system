import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/profile/models/user_profile_model.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  UserProfileModel? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get(ApiEndpoints.profile);
      _profile = UserProfileModel.fromJson(response);
    } catch (e) {
      _errorMessage = 'Không thể tải hồ sơ: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    DateTime? dateOfBirth,
    String? avatarUrl,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'avatar_url': avatarUrl,
      };

      final response = await _apiClient.put(ApiEndpoints.profile, body: body);
      _profile = UserProfileModel.fromJson(response);
      return true;
    } catch (e) {
      _errorMessage = 'Không thể cập nhật hồ sơ: ${e.toString()}';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
