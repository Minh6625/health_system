import '../models/user_model.dart';

class AuthService {
  Future<bool> login(UserModel user) async {
    await Future.delayed(const Duration(seconds: 2));

    // Giả lập kiểm tra
    if (user.email == "admin@gmail.com" && user.password == "123456") {
      return true;
    }

    return false;
  }
}
