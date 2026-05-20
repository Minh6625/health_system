import '../../../core/network/api_client.dart';
import '../models/access_profile_model.dart';
import '../models/user_search_model.dart';
import '../models/family_profile_snapshot.dart';
import '../models/linked_contact_medical_info_model.dart';
import '../models/linked_contact_model.dart';
import '../models/recent_alert_item.dart';
import 'package:flutter/foundation.dart';

/// P-4: thrown by ``FamilyRepository.getLinkedContactMedicalInfo`` when the
/// patient has not granted ``can_view_medical_info`` to the current user.
/// Distinct from a generic exception so the UI can render a "permission
/// not yet granted" empty state instead of a red error banner.
class MedicalInfoPermissionDeniedException implements Exception {
  const MedicalInfoPermissionDeniedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// P-4: thrown when the requested contact has no accepted relationship.
/// Different from ``MedicalInfoPermissionDeniedException`` so the UI can
/// surface a "stale link / contact removed" message rather than the
/// permission-toggle hint.
class MedicalInfoNotFoundException implements Exception {
  const MedicalInfoNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown by [FamilyRepository.fetchRecentAlerts] when the caregiver doesn't
/// have ``can_receive_alerts = true`` (or no accepted relationship at all).
///
/// Distinct from a generic ``Exception`` so the UI can switch into the
/// "permission not granted" banner state instead of showing a red error.
class RecentAlertsPermissionDeniedException implements Exception {
  const RecentAlertsPermissionDeniedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FamilyRepository {
  FamilyRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<FamilyProfileSnapshot>> getFamilyDashboard() async {
    try {
      final response = await _apiClient.get('/relationships/dashboard');
      if (response != null && response is List) {
        return response
            .map(
              (json) => FamilyProfileSnapshot.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting family dashboard: $e');
      throw Exception('Không thể tải dashboard.');
    }
  }

  Future<LinkedContactModel> getLinkedContactDetail(String id) async {
    try {
      final response = await _apiClient.get('/relationships/$id/detail');
      if (response != null && response is Map) {
        return LinkedContactModel.fromJson(Map<String, dynamic>.from(response));
      }
      throw Exception('Data is null');
    } catch (e) {
      debugPrint('Error getting linked contact detail: $e');
      throw Exception('Không thể tải chi tiết liên hệ.');
    }
  }

  /// P-4: fetch a linked contact's read-only medical profile.
  ///
  /// The current ``ApiClient`` collapses every non-2xx into a flat
  /// ``Exception`` whose message is the backend ``detail`` string, so we
  /// detect 403 vs 404 by matching the Vietnamese phrases from the
  /// backend's HTTPException details. Brittle if those copies change, but
  /// keeps the typed-exception surface here without invasive ApiClient
  /// changes — and the same Vietnamese strings are pinned by the backend
  /// HTTP-route tests, so a drift would fail there before it reached UI.
  Future<LinkedContactMedicalInfoModel> getLinkedContactMedicalInfo(
    String id,
  ) async {
    try {
      final response = await _apiClient.get('/relationships/$id/medical-info');
      if (response is Map) {
        return LinkedContactMedicalInfoModel.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw Exception('Phản hồi không hợp lệ.');
    } catch (e) {
      final raw = e.toString();
      if (raw.contains('chưa cho phép')) {
        throw MedicalInfoPermissionDeniedException(raw);
      }
      if (raw.contains('Không tìm thấy')) {
        throw MedicalInfoNotFoundException(raw);
      }
      debugPrint('Error getting linked contact medical info: $e');
      throw Exception('Không thể tải hồ sơ y tế của liên hệ.');
    }
  }

  /// Fetch the caregiver-feed of recent alerts for a single patient.
  ///
  /// Drives the "Cảnh báo gần đây" section on PersonDetailScreen.
  ///
  /// 403 from the backend (no accepted relationship OR
  /// ``can_receive_alerts = false``) is mapped to
  /// [RecentAlertsPermissionDeniedException] so the UI can render the
  /// dedicated banner instead of a red error. We match the English copy used
  /// by ``EmergencyService.get_recent_alerts_for_patient`` (the same string
  /// is asserted in the backend HTTP tests, so any drift fails there first).
  ///
  /// [days] / [limit] mirror the backend ``Query(ge=…, le=…)`` bounds.
  Future<RecentAlertsResponse> fetchRecentAlerts(
    int patientUserId, {
    int days = 7,
    int limit = 10,
  }) async {
    try {
      final response = await _apiClient.get(
        '/emergency/caregiver/patients/$patientUserId/recent-alerts'
        '?days=$days&limit=$limit',
      );
      if (response is Map) {
        return RecentAlertsResponse.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw Exception('Phản hồi không hợp lệ.');
    } catch (e) {
      final raw = e.toString();
      if (raw.contains('do not have permission') ||
          raw.contains('không có quyền')) {
        throw RecentAlertsPermissionDeniedException(raw);
      }
      debugPrint('Error fetching recent alerts: $e');
      throw Exception('Không thể tải cảnh báo gần đây.');
    }
  }

  /// Lấy danh sách bạn bè / người thân và các lời mời
  Future<List<Map<String, dynamic>>> getRelationships() async {
    try {
      final response = await _apiClient.get('/relationships');
      if (response != null && response is List) {
        return response
            .map((json) => Map<String, dynamic>.from(json as Map))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting relationships: $e');
      throw Exception('Không thể tải danh sách liên hệ.');
    }
  }

  /// Search for a user by phone or email
  Future<List<UserSearchModel>> searchUsers(String query) async {
    try {
      final response = await _apiClient.get(
        '/relationships/search?query=${Uri.encodeComponent(query)}',
      );

      if (response != null && response is List) {
        return response
            .map(
              (json) => UserSearchModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching users: $e');
      throw Exception('Không thể tìm kiếm người dùng. Vui lòng thử lại.');
    }
  }

  Future<List<AccessProfileModel>> getAccessProfiles() async {
    try {
      final response = await _apiClient.get('/access-profiles');
      if (response != null && response is List) {
        return response
            .map(
              (json) => AccessProfileModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();
      }
      return const <AccessProfileModel>[];
    } catch (e) {
      debugPrint('Error getting access profiles: $e');
      throw Exception('Không thể tải hồ sơ truy cập.');
    }
  }

  /// Request to connect with a user (Shared logic for both Phone and QR)
  Future<void> sendConnectionRequest({
    String? phone,
    String? email,
    int? targetUserId,
    String relationshipType = 'family',
    List<Map<String, dynamic>>? tags,
    String? primaryLabel,
  }) async {
    try {
      final body = <String, dynamic>{'relationship_type': relationshipType};

      if (phone != null) body['phone'] = phone;
      if (email != null) body['email'] = email;
      if (targetUserId != null) body['target_user_id'] = targetUserId;
      if (tags != null) body['tags'] = tags;
      if (primaryLabel != null) {
        body['primary_relationship_label'] = primaryLabel;
      }
      if (targetUserId != null) body['target_user_id'] = targetUserId;

      await _apiClient.post('/relationships/request', body: body);
    } catch (e) {
      debugPrint('Error sending connection request: $e');
      String errorMsg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('Network error:', '')
          .trim();
      throw Exception(errorMsg);
    }
  }

  /// Accept a relationship request
  Future<void> acceptRelationship(int relationshipId) async {
    try {
      await _apiClient.post(
        '/relationships/accept',
        body: {'relationship_id': relationshipId},
      );
    } catch (e) {
      debugPrint('Error accepting relationship: $e');
      String errorMsg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('Network error:', '')
          .trim();
      throw Exception(errorMsg);
    }
  }

  /// Update relationship permissions or type
  Future<void> updateRelationship(
    int relationshipId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _apiClient.put('/relationships/$relationshipId', body: data);
    } catch (e) {
      debugPrint('Error updating relationship: $e');
      String errorMsg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('Network error:', '')
          .trim();
      throw Exception(errorMsg);
    }
  }

  /// Remove or cancel a connection directly by relationship ID
  Future<void> removeRelationshipById(int relationshipId) async {
    try {
      await _apiClient.delete('/relationships/$relationshipId');
    } catch (e) {
      debugPrint('Error removing relationship: $e');
      String errorMsg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('Network error:', '')
          .trim();
      throw Exception(errorMsg);
    }
  }

  /// Cancel an existing connection request based on target user ID
  Future<void> cancelConnectionRequest(int targetUserId) async {
    try {
      final response = await _apiClient.get('/relationships');
      if (response != null && response is List) {
        int? relId;
        for (var item in response) {
          if ((item['patient_id'] == targetUserId ||
                  item['caregiver_id'] == targetUserId) &&
              item['status'] == 'pending') {
            relId = item['id'];
            break;
          }
        }
        if (relId != null) {
          await _apiClient.delete('/relationships/$relId');
        } else {
          throw Exception('Không tìm thấy lời mời để hủy.');
        }
      }
    } catch (e) {
      debugPrint('Error canceling connection request: $e');
      String errorMsg = e
          .toString()
          .replaceAll('Exception:', '')
          .replaceAll('Network error:', '')
          .trim();
      throw Exception(errorMsg);
    }
  }
}
