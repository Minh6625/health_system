import 'package:flutter/material.dart';
import 'package:healthguard/core/constants/api_endpoints.dart';
import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/profile/models/user_profile_model.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  UserProfileModel? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorMessage;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDeleting => _isDeleting;
  String? get errorMessage => _errorMessage;

  void clearProfile() {
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }

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
    String? gender,
    String? bloodType,
    double? heightCm,
    double? weightKg,
    List<dynamic>? medications,
    List<dynamic>? allergies,
    List<String>? medicalConditions,
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
        'gender': gender,
        'blood_type': bloodType,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'medications': medications,
        'allergies': allergies,
        'medical_conditions': medicalConditions,
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

  Future<bool> deleteAccount({required String password}) async {
    _isDeleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiClient.delete(
        ApiEndpoints.profile,
        body: {'password': password},
      );
      _profile = null;
      return true;
    } catch (e) {
      _errorMessage = 'Không thể xóa tài khoản: ${e.toString()}';
      return false;
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }
}

