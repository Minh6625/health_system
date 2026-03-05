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

    // Validate full_name: only letters, Vietnamese diacritics, and spaces
    if (user.fullName?.trim().isEmpty ?? true) {
      message = 'Vui lòng nhập họ tên';
      notifyListeners();
      return false;
    }

    if ((user.fullName?.trim().length ?? 0) < 2) {
      message = 'Họ tên phải có ít nhất 2 ký tự';
      notifyListeners();
      return false;
    }

    if ((user.fullName?.trim().length ?? 0) > 100) {
      message = 'Họ tên không thể vượt quá 100 ký tự';
      notifyListeners();
      return false;
    }

    // Only letters, Vietnamese diacritics (À-ỿ), and spaces allowed
    final namePattern = RegExp(r'^[a-zA-ZÀ-ỿ\s]+$');
    if (!namePattern.hasMatch(user.fullName?.trim() ?? '')) {
      message =
          'Họ tên chỉ được chứa chữ cái. Không được phép dùng số hoặc ký tự đặc biệt';
      notifyListeners();
      return false;
    }

    if (user.password.isEmpty || user.password.length < 8) {
      message = 'Mật khẩu phải có ít nhất 8 ký tự';
      notifyListeners();
      return false;
    }

    // Validate date of birth if provided
    if (user.dateOfBirth != null) {
      final age =
          DateTime.now().year -
          user.dateOfBirth!.year -
          (DateTime.now().month < user.dateOfBirth!.month ||
                  (DateTime.now().month == user.dateOfBirth!.month &&
                      DateTime.now().day < user.dateOfBirth!.day)
              ? 1
              : 0);

      if (age < 18) {
        message = 'Bạn phải đủ 18 tuổi để đăng ký';
        notifyListeners();
        return false;
      }

      if (age > 150) {
        message = 'Ngày sinh không hợp lệ';
        notifyListeners();
        return false;
      }
    } else {
      message = 'Vui lòng chọn ngày sinh';
      notifyListeners();
      return false;
    }

    // Validate phone if provided
    if (user.phone != null && user.phone!.isNotEmpty) {
      final phone = user.phone!.replaceAll(RegExp(r'[^\d]'), '');
      if (phone.length < 10 || phone.length > 15) {
        message = 'Số điện thoại phải có từ 10 đến 15 chữ số';
        notifyListeners();
        return false;
      }
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
    if (!Validators.isValidEmail(email)) {
      message = 'Email không hợp lệ';
      notifyListeners();
      return false;
    }

    isLoading = true;
    message = null;
    notifyListeners();

    try {
      final response = await repository.resendVerification(email);
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
