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
  bool isBootstrapping = false;
  bool sessionResolved = false;
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
        await _applyAuthenticatedSession(
          response,
          fallbackRefreshToken: response.refreshToken,
        );
        message = response.message;
        notifyListeners();
        return true;
      }

      message = response.message;
      notifyListeners();
      return false;
    } catch (e) {
      isLoading = false;
      message = 'Lỗi kết nối: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> bootstrapSession() async {
    if (isBootstrapping) {
      return isAuthenticated;
    }

    isBootstrapping = true;
    notifyListeners();

    try {
      final storedAccessToken = await _tokenStorageService.readAccessToken();
      final storedRefreshToken = await _tokenStorageService.readRefreshToken();
      final storedUser = await _tokenStorageService.readUser();

      if (!_hasValidSessionSnapshot(storedAccessToken, storedRefreshToken)) {
        await _clearSessionState(notify: false);
        sessionResolved = true;
        return false;
      }

      accessToken = storedAccessToken;
      refreshToken = storedRefreshToken;
      currentUser = storedUser;

      if (_canRestoreStoredSession(storedAccessToken, storedUser)) {
        message = null;
        sessionResolved = true;
        return true;
      }

      if (!_hasRefreshToken(storedRefreshToken)) {
        await _clearSessionState(notify: false);
        sessionResolved = true;
        return false;
      }

      final response = await repository.refreshToken(storedRefreshToken!);
      if (!_canApplyAuthenticatedResponse(response)) {
        await _clearSessionState(notify: false);
        message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
        sessionResolved = true;
        return false;
      }

      await _applyAuthenticatedSession(
        response,
        fallbackRefreshToken: storedRefreshToken,
      );
      message = null;
      sessionResolved = true;
      return true;
    } catch (error) {
      await _clearSessionState(notify: false);
      message = _buildBootstrapErrorMessage(error);
      sessionResolved = true;
      return false;
    } finally {
      isBootstrapping = false;
      notifyListeners();
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

    // Only letters, Unicode characters (for all VN diacritics), and spaces allowed
    final namePattern = RegExp(r'^[\p{L}\s]+$', unicode: true);
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

      if (age < 16) {
        message = 'Bạn phải đủ 16 tuổi để đăng ký';
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
    if (user.phone != null && user.phone!.trim().isNotEmpty) {
      final phone = user.phone!.trim();
      if (!RegExp(r'^\d+$').hasMatch(phone)) {
        message = 'Số điện thoại chỉ được chứa ký tự số';
        notifyListeners();
        return false;
      }
      if (phone.length < 10 || phone.length > 11) {
        message = 'Số điện thoại phải có từ 10 đến 11 chữ số';
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

  Future<bool> verifyEmail(String email, String code) async {
    isLoading = true;
    message = null;
    notifyListeners();

    try {
      final response = await repository.verifyEmail(email, code);
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
    await _clearSessionState(notify: false);
    message = 'Đã đăng xuất';
    notifyListeners();
  }

  void clearMessage() {
    message = null;
    notifyListeners();
  }

  Future<void> _applyAuthenticatedSession(
    AuthResponse response, {
    String? fallbackRefreshToken,
  }) async {
    final nextAccessToken = response.accessToken;
    final nextUser = response.user;
    if (nextAccessToken == null || nextAccessToken.isEmpty || nextUser == null) {
      return;
    }

    accessToken = nextAccessToken;
    refreshToken = response.refreshToken ?? fallbackRefreshToken;
    currentUser = nextUser;
    sessionResolved = true;

    await _tokenStorageService.saveSession(
      accessToken: nextAccessToken,
      refreshToken: refreshToken,
      user: nextUser,
    );
  }

  bool _hasValidSessionSnapshot(String? storedAccessToken, String? storedRefreshToken) {
    final hasAccessToken = storedAccessToken != null && storedAccessToken.isNotEmpty;
    final hasRefreshToken = storedRefreshToken != null && storedRefreshToken.isNotEmpty;
    return hasAccessToken || hasRefreshToken;
  }

  bool _canRestoreStoredSession(String? storedAccessToken, UserData? storedUser) {
    return storedAccessToken != null && storedAccessToken.isNotEmpty && storedUser != null;
  }

  bool _hasRefreshToken(String? storedRefreshToken) {
    return storedRefreshToken != null && storedRefreshToken.isNotEmpty;
  }

  bool _canApplyAuthenticatedResponse(AuthResponse response) {
    final nextAccessToken = response.accessToken;
    return response.success &&
        nextAccessToken != null &&
        nextAccessToken.isNotEmpty &&
        response.user != null;
  }

  String _buildBootstrapErrorMessage(Object error) {
    if (error is Exception) {
      return 'Không thể khôi phục phiên đăng nhập.';
    }

    return 'Đã xảy ra lỗi khi khôi phục phiên đăng nhập.';
  }

  Future<void> _clearSessionState({required bool notify}) async {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
    await _tokenStorageService.clearTokens();
    if (notify) {
      notifyListeners();
    }
  }
}
