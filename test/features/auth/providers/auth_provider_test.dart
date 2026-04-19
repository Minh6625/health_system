import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/models/user_model.dart';
import 'package:healthguard/features/auth/providers/auth_provider.dart';
import 'package:healthguard/features/auth/repositories/auth_repository.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_provider_test.mocks.dart';

String _buildJwtWithExp(DateTime expiresAt) {
  String encodeSegment(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${encodeSegment({'alg': 'HS256', 'typ': 'JWT'})}.${encodeSegment({'exp': expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000})}.signature';
}

@GenerateMocks([AuthRepository])
void main() {
  late AuthProvider authProvider;
  late MockAuthRepository mockRepository;
  late AuthSessionService sessionService;

  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    sessionService = AuthSessionService();
    mockRepository = MockAuthRepository();
    authProvider = AuthProvider(mockRepository, sessionService: sessionService);
  });

  group('AuthProvider.register', () {
    test('successful registration returns true', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'user',
        dateOfBirth: DateTime(1990, 1, 1),
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
        role: 'user',
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
        role: 'user',
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
        role: 'user',
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
        role: 'user',
        dateOfBirth: DateTime(1990, 1, 1),
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
        role: 'user',
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
        role: 'user',
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
        role: 'user',
        dateOfBirth: DateTime(1990, 1, 1),
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
        role: 'user',
        dateOfBirth: DateTime(1990, 1, 1),
      );

      when(mockRepository.register(user)).thenThrow(Exception('Network error'));

      // Act
      final result = await authProvider.register(user);

      // Assert
      expect(result, false);
      expect(authProvider.message, contains('Lỗi'));
      expect(authProvider.isLoading, false);
    });

    test('loading state is set during registration', () async {
      // Arrange
      final user = UserModel(
        email: 'test@example.com',
        fullName: 'Test User',
        password: 'StrongPass123!',
        role: 'user',
        dateOfBirth: DateTime(1990, 1, 1),
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

  group('AuthProvider.bootstrapSession', () {
    test(
      'restores session from secure storage when user snapshot exists',
      () async {
        final accessToken = _buildJwtWithExp(
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
        FlutterSecureStoragePlatform
            .instance = TestFlutterSecureStoragePlatform({
          'access_token': accessToken,
          'refresh_token': 'stored-refresh-token',
          'user_session':
              '{"user_id":1,"email":"elder@example.com","full_name":"Nguyen Van A","role":"patient"}',
        });
        authProvider = AuthProvider(
          mockRepository,
          sessionService: AuthSessionService(),
        );

        final result = await authProvider.bootstrapSession();

        expect(result, true);
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.accessToken, accessToken);
        expect(authProvider.refreshToken, 'stored-refresh-token');
        expect(authProvider.currentUser?.email, 'elder@example.com');
        verifyNever(mockRepository.refreshToken('stored-refresh-token'));
      },
    );

    test(
      'refreshes expired access token when a refresh token is available',
      () async {
        final expiredAccessToken = _buildJwtWithExp(
          DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        );
        FlutterSecureStoragePlatform
            .instance = TestFlutterSecureStoragePlatform({
          'access_token': expiredAccessToken,
          'refresh_token': 'stored-refresh-token',
          'user_session':
              '{"user_id":1,"email":"elder@example.com","full_name":"Nguyen Van A","role":"patient"}',
        });
        authProvider = AuthProvider(
          mockRepository,
          sessionService: AuthSessionService(),
        );

        when(mockRepository.refreshToken('stored-refresh-token')).thenAnswer(
          (_) async => AuthResponse(
            success: true,
            message: 'Token đã được làm mới',
            accessToken: 'new-access-token',
            user: UserData(
              userId: 3,
              email: 'fresh@example.com',
              fullName: 'Pham Thi C',
              role: 'patient',
            ),
          ),
        );

        final result = await authProvider.bootstrapSession();

        expect(result, true);
        expect(authProvider.isAuthenticated, true);
        expect(authProvider.accessToken, 'new-access-token');
        expect(authProvider.refreshToken, 'stored-refresh-token');
        expect(authProvider.currentUser?.email, 'fresh@example.com');
        verify(mockRepository.refreshToken('stored-refresh-token')).called(1);
      },
    );

    test('refreshes session when stored user snapshot is missing', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'refresh_token': 'stored-refresh-token',
      });
      authProvider = AuthProvider(
        mockRepository,
        sessionService: AuthSessionService(),
      );

      when(mockRepository.refreshToken('stored-refresh-token')).thenAnswer(
        (_) async => AuthResponse(
          success: true,
          message: 'Token đã được làm mới',
          accessToken: 'new-access-token',
          user: UserData(
            userId: 2,
            email: 'caregiver@example.com',
            fullName: 'Le Thi B',
            role: 'caregiver',
          ),
        ),
      );

      final result = await authProvider.bootstrapSession();

      expect(result, true);
      expect(authProvider.isAuthenticated, true);
      expect(authProvider.accessToken, 'new-access-token');
      expect(authProvider.refreshToken, 'stored-refresh-token');
      expect(authProvider.currentUser?.email, 'caregiver@example.com');
      verify(mockRepository.refreshToken('stored-refresh-token')).called(1);
    });

    test('clears invalid session when refresh fails', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'refresh_token': 'expired-refresh-token',
      });
      authProvider = AuthProvider(
        mockRepository,
        sessionService: AuthSessionService(),
      );

      when(mockRepository.refreshToken('expired-refresh-token')).thenAnswer(
        (_) async => AuthResponse(
          success: false,
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        ),
      );

      final result = await authProvider.bootstrapSession();

      expect(result, false);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.accessToken, null);
      expect(authProvider.refreshToken, null);
      expect(
        authProvider.message,
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
      verify(mockRepository.refreshToken('expired-refresh-token')).called(1);
    });

    test('logout clears stored session snapshot', () async {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
        'access_token': 'stored-access-token',
        'refresh_token': 'stored-refresh-token',
        'user_session':
            '{"user_id":1,"email":"elder@example.com","full_name":"Nguyen Van A","role":"patient"}',
      });
      authProvider = AuthProvider(
        mockRepository,
        sessionService: AuthSessionService(),
      );

      await authProvider.bootstrapSession();
      await authProvider.logout();

      const storage = FlutterSecureStorage();
      final accessToken = await storage.read(key: 'access_token');
      final refreshToken = await storage.read(key: 'refresh_token');
      final userSession = await storage.read(key: 'user_session');

      expect(authProvider.isAuthenticated, false);
      expect(authProvider.accessToken, null);
      expect(authProvider.refreshToken, null);
      expect(authProvider.currentUser, null);
      expect(authProvider.message, 'Đã đăng xuất');
      expect(accessToken, null);
      expect(refreshToken, null);
      expect(userSession, null);
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

  group('AuthProvider session events', () {
    test(
      'reacts to session expiration emitted by the shared session service',
      () async {
        await sessionService.applyAuthenticatedResponse(
          AuthResponse(
            success: true,
            message: 'Đăng nhập thành công',
            accessToken: _buildJwtWithExp(
              DateTime.now().toUtc().add(const Duration(hours: 1)),
            ),
            refreshToken: 'refresh-token',
            user: UserData(
              userId: 9,
              email: 'elder@example.com',
              fullName: 'Nguyen Van A',
              role: 'patient',
            ),
          ),
          fallbackRefreshToken: 'refresh-token',
        );

        await Future<void>.delayed(Duration.zero);
        expect(authProvider.isAuthenticated, true);

        await sessionService.clearSession(
          message: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
        await Future<void>.delayed(Duration.zero);

        expect(authProvider.isAuthenticated, false);
        expect(authProvider.accessToken, null);
        expect(authProvider.currentUser, null);
        expect(
          authProvider.message,
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      },
    );
  });
}
