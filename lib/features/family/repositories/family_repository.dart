import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/family/models/access_profile.dart';
import 'package:healthguard/features/family/models/relationship.dart';
import 'package:healthguard/features/family/models/user_search_result.dart';

class FamilyRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<AccessProfile>> getAccessProfiles() async {
    try {
      final List<dynamic> result =
          await _apiClient.get('/access-profiles') as List<dynamic>;
      return result.map((json) => AccessProfile.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Không thể tải danh sách hồ sơ: ${e.toString()}');
    }
  }

  Future<List<Relationship>> getRelationships() async {
    try {
      final List<dynamic> result =
          await _apiClient.get('/relationships') as List<dynamic>;
      return result.map((json) => Relationship.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Không thể tải danh sách kết nối: ${e.toString()}');
    }
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    try {
      final List<dynamic> result = await _apiClient.get(
        '/relationships/search',
        queryParams: {'query': query},
      );
      return result.map((json) => UserSearchResult.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi tìm kiếm: \${e.toString()}');
    }
  }

  Future<Relationship> requestAccess(String email) async {
    try {
      final json = await _apiClient.post(
        '/relationships/request',
        body: {'email': email},
      );
      return Relationship.fromJson(json);
    } catch (e) {
      throw Exception('Lỗi gửi yêu cầu kết nối: ${e.toString()}');
    }
  }

  Future<Relationship> acceptRequest(int relationshipId) async {
    try {
      final json = await _apiClient.post(
        '/relationships/accept',
        body: {'relationship_id': relationshipId},
      );
      return Relationship.fromJson(json);
    } catch (e) {
      throw Exception('Lỗi xác nhận: ${e.toString()}');
    }
  }

  Future<void> deleteRelationship(int relationshipId) async {
    try {
      await _apiClient.delete('/relationships/$relationshipId');
    } catch (e) {
      throw Exception('Lỗi xóa kết nối: ${e.toString()}');
    }
  }
}
