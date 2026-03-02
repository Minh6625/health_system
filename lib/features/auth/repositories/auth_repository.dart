import 'package:health_system/core/network/api_client.dart';
import 'package:health_system/features/auth/models/auth_response_model.dart';
import 'package:health_system/features/auth/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<AuthResponse> login(UserModel user) async {
    try {
      final result = await _apiClient.post('/auth/login', body: user.toJson());
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> register(UserModel user) async {
    try {
      final result = await _apiClient.post(
        '/auth/register',
        body: user.toJson(),
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }
}
