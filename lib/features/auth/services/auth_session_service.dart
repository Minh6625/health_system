import 'dart:async';
import 'dart:convert';

import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/services/token_storage_service.dart';

typedef AuthRefreshHandler = Future<AuthResponse> Function(String refreshToken);

class AuthSessionSnapshot {
  const AuthSessionSnapshot({this.accessToken, this.refreshToken, this.user});

  final String? accessToken;
  final String? refreshToken;
  final UserData? user;

  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;
  bool get hasRefreshToken => refreshToken != null && refreshToken!.isNotEmpty;
  bool get hasAnyToken => hasAccessToken || hasRefreshToken;
}

class AuthSessionUpdate {
  const AuthSessionUpdate({
    required this.snapshot,
    required this.sessionResolved,
    this.message,
  });

  final AuthSessionSnapshot snapshot;
  final bool sessionResolved;
  final String? message;
}

class AuthSessionRefreshResult {
  const AuthSessionRefreshResult({
    required this.success,
    required this.snapshot,
    this.message,
  });

  final bool success;
  final AuthSessionSnapshot snapshot;
  final String? message;
}

class AuthSessionService {
  AuthSessionService({TokenStorageService? tokenStorageService})
    : _tokenStorageService = tokenStorageService ?? TokenStorageService();

  static final AuthSessionService shared = AuthSessionService();

  final TokenStorageService _tokenStorageService;
  final StreamController<AuthSessionUpdate> _updates =
      StreamController<AuthSessionUpdate>.broadcast();

  Completer<AuthSessionRefreshResult>? _refreshCompleter;

  Stream<AuthSessionUpdate> get updates => _updates.stream;

  Future<AuthSessionSnapshot> readStoredSession() async {
    final accessToken = await _tokenStorageService.readAccessToken();
    final refreshToken = await _tokenStorageService.readRefreshToken();
    final user = await _tokenStorageService.readUser();

    return AuthSessionSnapshot(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  bool isAccessTokenUsable(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final segments = token.split('.');
      if (segments.length != 3) {
        return false;
      }

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      if (payload is! Map<String, dynamic>) {
        return false;
      }

      final exp = payload['exp'];
      if (exp is! num) {
        return false;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
      return expiresAt.isAfter(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> applyAuthenticatedResponse(
    AuthResponse response, {
    String? fallbackRefreshToken,
  }) async {
    final nextAccessToken = response.accessToken;
    final nextUser = response.user;

    if (nextAccessToken == null ||
        nextAccessToken.isEmpty ||
        nextUser == null) {
      return;
    }

    final snapshot = AuthSessionSnapshot(
      accessToken: nextAccessToken,
      refreshToken: response.refreshToken ?? fallbackRefreshToken,
      user: nextUser,
    );

    await _persistSnapshot(snapshot);
    _emitUpdate(snapshot, sessionResolved: true);
  }

  Future<AuthSessionRefreshResult> restoreSession({
    required AuthRefreshHandler refreshTokenHandler,
  }) async {
    final snapshot = await readStoredSession();

    if (!snapshot.hasAnyToken) {
      await clearSession();
      return const AuthSessionRefreshResult(
        success: false,
        snapshot: AuthSessionSnapshot(),
      );
    }

    if (isAccessTokenUsable(snapshot.accessToken) && snapshot.user != null) {
      _emitUpdate(snapshot, sessionResolved: true);
      return AuthSessionRefreshResult(success: true, snapshot: snapshot);
    }

    return refreshSession(
      refreshTokenHandler: refreshTokenHandler,
      failureMessage: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    );
  }

  Future<AuthSessionRefreshResult> refreshSession({
    required AuthRefreshHandler refreshTokenHandler,
    required String failureMessage,
  }) async {
    final ongoingRefresh = _refreshCompleter;
    if (ongoingRefresh != null) {
      return ongoingRefresh.future;
    }

    final completer = Completer<AuthSessionRefreshResult>();
    _refreshCompleter = completer;

    try {
      final snapshot = await readStoredSession();
      final refreshToken = snapshot.refreshToken;

      if (refreshToken == null || refreshToken.isEmpty) {
        await clearSession(message: failureMessage);
        completer.complete(
          AuthSessionRefreshResult(
            success: false,
            snapshot: const AuthSessionSnapshot(),
            message: failureMessage,
          ),
        );
        return completer.future;
      }

      final response = await refreshTokenHandler(refreshToken);
      if (!_canApplyAuthenticatedResponse(response)) {
        await clearSession(message: failureMessage);
        completer.complete(
          AuthSessionRefreshResult(
            success: false,
            snapshot: const AuthSessionSnapshot(),
            message: response.message,
          ),
        );
        return completer.future;
      }

      await applyAuthenticatedResponse(
        response,
        fallbackRefreshToken: refreshToken,
      );
      final refreshedSnapshot = await readStoredSession();
      completer.complete(
        AuthSessionRefreshResult(success: true, snapshot: refreshedSnapshot),
      );
      return completer.future;
    } catch (error) {
      await clearSession(message: failureMessage);
      completer.complete(
        AuthSessionRefreshResult(
          success: false,
          snapshot: const AuthSessionSnapshot(),
          message: error.toString(),
        ),
      );
      return completer.future;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> clearSession({String? message}) async {
    await _tokenStorageService.clearTokens();
    _emitUpdate(
      const AuthSessionSnapshot(),
      sessionResolved: true,
      message: message,
    );
  }

  bool _canApplyAuthenticatedResponse(AuthResponse response) {
    final nextAccessToken = response.accessToken;
    return response.success &&
        nextAccessToken != null &&
        nextAccessToken.isNotEmpty &&
        response.user != null;
  }

  Future<void> _persistSnapshot(AuthSessionSnapshot snapshot) async {
    final accessToken = snapshot.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      await _tokenStorageService.clearTokens();
      return;
    }

    await _tokenStorageService.saveSession(
      accessToken: accessToken,
      refreshToken: snapshot.refreshToken,
      user: snapshot.user,
    );
  }

  void _emitUpdate(
    AuthSessionSnapshot snapshot, {
    required bool sessionResolved,
    String? message,
  }) {
    if (_updates.isClosed) {
      return;
    }

    _updates.add(
      AuthSessionUpdate(
        snapshot: snapshot,
        sessionResolved: sessionResolved,
        message: message,
      ),
    );
  }
}
