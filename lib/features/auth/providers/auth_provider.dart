import 'package:flutter/foundation.dart';
import 'package:healthguard/core/utils/validators.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/models/user_model.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/services/token_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository repository;
  final TokenStorageService _tokenStorageService = TokenStorageService();

  AuthProvider(this.repository);

  bool isLoading = false;
  String? message;
  String? accessToken;
  String? refreshToken;
  UserData? currentUser;

  bool get isAuthenticated => accessToken != null && currentUser != null;

  Future<bool> login(UserModel user) async {
    if (!Validators.isValidEmail(user.email)) {
      message = 'Email không hợp lệ';
      notifyListeners();
      return false;
    }

    if (user.password.isEmpty) {
      message = 'Vui lòng nhập mật khẩu';
      notifyListeners();
      return false;
    }

    isLoading = true;
    message = null;
    notifyListeners();

    try {
      final response = await repository.login(user);
      isLoading = false;

      if (response.success) {
        accessToken = response.accessToken;
        refreshToken = response.refreshToken;
        currentUser = response.user;

        if (accessToken != null) {
          await _tokenStorageService.saveTokens(
            accessToken: accessToken!,
            refreshToken: refreshToken,
          );
        }

        message = response.message;
        notifyListeners();
        return true;
      } else {
        message = response.message;
        notifyListeners();
        return false;
      }
    } catch (e) {
      isLoading = false;
      message = 'Lỗi kết nối: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(UserModel user) async {
    if (!Validators.isValidEmail(user.email)) {
      message = 'Email không hợp lệ';
      notifyListeners();
      return false;
    }

    if (!Validators.isStrongPassword(user.password)) {
      message = 'Mật khẩu phải có ít nhất 6 ký tự';
      notifyListeners();
      return false;
    }

    isLoading = true;
    message = null;
    notifyListeners();

    try {
      final response = await repository.register(user);
      isLoading = false;
      message = response.message;
      notifyListeners();
      return response.success;
    } catch (e) {
      isLoading = false;
      message = 'Lỗi kết nối: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmail(String verificationToken) async {
    isLoading = true;
    message = null;
    notifyListeners();

    try {
      final response = await repository.verifyEmail(verificationToken);
      isLoading = false;
      message = response.message;
      notifyListeners();
      return response.success;
    } catch (e) {
      isLoading = false;
      message = 'Lỗi xác thực: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerificationToken(String email) async {
    try {
      // This would require a new endpoint in the backend
      // For now, returning false with a message
      message = 'Chức năng gửi lại token sẽ được cập nhật';
      notifyListeners();
      return false;
    } catch (e) {
      message = 'Lỗi: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
    await _tokenStorageService.clearTokens();
    message = 'Đã đăng xuất';
    notifyListeners();
  }

  void clearMessage() {
    message = null;
    notifyListeners();
  }
}
