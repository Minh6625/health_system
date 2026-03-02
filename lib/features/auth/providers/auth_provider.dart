import 'package:flutter/foundation.dart';
import 'package:health_system/core/utils/validators.dart';
import 'package:health_system/features/auth/models/auth_response_model.dart';
import 'package:health_system/features/auth/models/user_model.dart';
import 'package:health_system/features/auth/repositories/auth_repository.dart';
import 'package:health_system/features/auth/services/token_storage_service.dart';

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
