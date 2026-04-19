import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';

class TokenStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userSessionKey = 'user_session';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    UserData? user,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } else {
      await _storage.delete(key: _refreshTokenKey);
    }
    if (user != null) {
      await _storage.write(key: _userSessionKey, value: jsonEncode(user.toJson()));
    } else {
      await _storage.delete(key: _userSessionKey);
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await saveSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<String?> readAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<UserData?> readUser() async {
    final rawUser = await _storage.read(key: _userSessionKey);
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return UserData.fromJson(decoded);
      }
      await _storage.delete(key: _userSessionKey);
    } catch (error) {
      await _storage.delete(key: _userSessionKey);
      if (error is Error) {
        rethrow;
      }
    }

    return null;
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userSessionKey);
  }
}
