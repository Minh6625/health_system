import 'package:healthguard/core/network/api_client.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<AuthResponse> login(UserModel user) async {
    try {
      final result = await _apiClient.post(
        '/auth/login',
        body: {'email': user.email, 'password': user.password},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final result = await _apiClient.post(
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
  }

  Future<AuthResponse> register(UserModel user) async {
    try {
      final result = await _apiClient.post(
        '/auth/register',
        body: user.toJson(),
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> verifyEmail(String email, String code) async {
    try {
      final result = await _apiClient.post(
        '/auth/verify-email',
        body: {'email': email, 'code': code},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> resendVerification(String email) async {
    try {
      final result = await _apiClient.post(
        '/auth/resend-verification',
        body: {'email': email},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> forgotPassword(String email) async {
    try {
      final result = await _apiClient.post(
        '/auth/forgot-password',
        body: {'email': email},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      final result = await _apiClient.post(
        '/auth/reset-password',
        body: {'email': email, 'code': code, 'new_password': newPassword},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> verifyResetOtp(String email, String code) async {
    try {
      final result = await _apiClient.post(
        '/auth/verify-reset-otp',
        body: {'email': email, 'code': code},
        requiresAuth: false,
      );
      return AuthResponse.fromJson(result);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối: ${e.toString()}',
      );
    }
  }

  Future<AuthResponse> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final result = await _apiClient.post(
        '/auth/change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
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
