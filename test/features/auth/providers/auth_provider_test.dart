import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/models/user_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_provider_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late AuthProvider authProvider;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    authProvider = AuthProvider(mockRepository);
  });

  group('AuthProvider.register', () {
    test('successful registration returns true', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'patient',
      );
      
      final response = AuthResponse(
        success: true,
        message: 'Đăng ký thành công',
        verificationToken: 'token123',
      );

      when(mockRepository.register(user)).thenAnswer((_) async => response);

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, true);
      expect(authProvider.message, 'Đăng ký thành công');
      expect(authProvider.isLoading, false);
      verify(mockRepository.register(user)).called(1);
    });

    test('invalid email returns false', () async {
      // Arrange
      final user = UserModel(
        email: 'invalid-email',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'patient',
      );

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, 'Email không hợp lệ');
      expect(authProvider.isLoading, false);
      verifyNever(mockRepository.register(user));
    });

    test('invalid full name with numbers returns false', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test123',
        password: 'StrongPass123!',
        role: 'patient',
      );

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, contains('Họ tên'));
      expect(authProvider.isLoading, false);
      verifyNever(mockRepository.register(user));
    });

    test('invalid full name with special characters returns false', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test@User#',
        password: 'StrongPass123!',
        role: 'patient',
      );

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, contains('Họ tên'));
      expect(authProvider.isLoading, false);
    });

    test('valid Vietnamese full name with diacritics succeeds', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Nguyễn Văn Anh',
        password: 'StrongPass123!',
        role: 'patient',
      );
      
      final response = AuthResponse(
        success: true,
        message: 'Đăng ký thành công',
        verificationToken: 'token123',
      );

      when(mockRepository.register(user)).thenAnswer((_) async => response);

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, true);
      expect(authProvider.message, 'Đăng ký thành công');
      verify(mockRepository.register(user)).called(1);
    });

    test('empty full name returns false', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: '',
        password: 'StrongPass123!',
        role: 'patient',
      );

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, contains('Vui lòng nhập họ tên'));
      expect(authProvider.isLoading, false);
    });

    test('short password returns false with error from backend', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'Pass1!',
        role: 'patient',
      );
      
      final response = AuthResponse(
        success: false,
        message: 'Mật khẩu phải có ít nhất 8 ký tự',
      );

      when(mockRepository.register(user)).thenAnswer((_) async => response);

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, 'Mật khẩu phải có ít nhất 8 ký tự');
      expect(authProvider.isLoading, false);
    });

    test('registration failure shows error message', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'patient',
      );
      
      final response = AuthResponse(
        success: false,
        message: 'Email đã tồn tại',
      );

      when(mockRepository.register(user)).thenAnswer((_) async => response);

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, 'Email đã tồn tại');
      expect(authProvider.isLoading, false);
    });

    test('network error returns false with error message', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'patient',
      );

      when(mockRepository.register(user)).thenThrow(Exception('Network error'));

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, contains('lỗi'));
      expect(authProvider.isLoading, false);
    });

    test('loading state is set during registration', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'patient',
      );
      
      final response = AuthResponse(
        success: true,
        message: 'Đăng ký thành công',
        verificationToken: 'token123',
      );

      when(mockRepository.register(user)).thenAnswer((_) async {
        // Verify isLoading is true during execution
        expect(authProvider.isLoading, true);
        return response;
      });

      // Act
      await authProvider.register(user);

      // Assert - isLoading should be false after completion
      expect(authProvider.isLoading, false);
    });
  });

  group('AuthProvider.clearMessage', () {
    test('clears message', () {
      // Arrange
      authProvider.message = 'Test message';

      // Act
      authProvider.clearMessage();

      // Assert
      expect(authProvider.message, null);
    });
  });
}
