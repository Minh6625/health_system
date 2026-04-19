import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';

void main() {
  group('AuthResponse.fromJson', () {
    test('reads verification_code responses from backend', () {
      final response = AuthResponse.fromJson({
        'success': true,
        'message': 'Đăng ký thành công',
        'verification_code': '123456',
      });

      expect(response.success, true);
      expect(response.verificationToken, '123456');
    });

    test('keeps compatibility with verification_token payloads', () {
      final response = AuthResponse.fromJson({
        'success': true,
        'message': 'Đăng ký thành công',
        'verification_token': '654321',
      });

      expect(response.verificationToken, '654321');
    });
  });
}
