import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:healthguard/core/network/risk_contract_version.dart';
import 'package:healthguard/features/auth/models/auth_response_model.dart';
import 'package:healthguard/features/auth/services/auth_session_service.dart';
import 'package:http/http.dart' as http;

class ApiRequestException implements Exception {
  const ApiRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._internal({
    http.Client? httpClient,
    AuthSessionService? sessionService,
    String? baseUrlOverride,
  }) : _httpClient = httpClient ?? http.Client(),
       _sessionService = sessionService ?? AuthSessionService.shared,
       _baseUrlOverride = baseUrlOverride;

  @visibleForTesting
  ApiClient.test({
    http.Client? httpClient,
    AuthSessionService? sessionService,
    String? baseUrlOverride,
  }) : _httpClient = httpClient ?? http.Client(),
       _sessionService = sessionService ?? AuthSessionService(),
       _baseUrlOverride = baseUrlOverride;

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  final http.Client _httpClient;
  final AuthSessionService _sessionService;
  final String? _baseUrlOverride;

  int? targetProfileId;

  String get baseUrl {
    final overrideUrl = _baseUrlOverride;
    if (overrideUrl != null && overrideUrl.isNotEmpty) {
      return overrideUrl;
    }

    String url = dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000/api/v1/mobile';
    if (kIsWeb) {
      url = url.replaceFirst('10.0.2.2', '127.0.0.1');
    }
    return url;
  }

  Future<Map<String, String>> _buildHeaders({
    bool requiresAuth = true,
    int? requestTargetProfileId,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = (await _sessionService.readStoredSession()).accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final resolvedTargetProfileId = requestTargetProfileId ?? targetProfileId;
    if (resolvedTargetProfileId != null) {
      headers['X-Target-Profile-Id'] = resolvedTargetProfileId.toString();
    }
    return headers;
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int? targetProfileId,
  }) {
    final url = Uri.parse('$baseUrl$path');
    return _sendJsonRequest(
      requiresAuth: requiresAuth,
      requestTargetProfileId: targetProfileId,
      isSuccess: (response) =>
          response.statusCode == 200 || response.statusCode == 201,
      send: (headers) => _httpClient
          .post(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10)),
    );
  }

  Future<dynamic> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? queryParams,
    int? targetProfileId,
  }) {
    Uri url = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      url = url.replace(queryParameters: _normalizeQueryParams(queryParams));
    }

    return _sendJsonRequest(
      requiresAuth: requiresAuth,
      requestTargetProfileId: targetProfileId,
      isSuccess: (response) => response.statusCode == 200,
      send: (headers) => _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10)),
    );
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int? targetProfileId,
  }) {
    final url = Uri.parse('$baseUrl$path');
    return _sendJsonRequest(
      requiresAuth: requiresAuth,
      requestTargetProfileId: targetProfileId,
      isSuccess: (response) => response.statusCode == 200,
      send: (headers) => _httpClient
          .patch(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10)),
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int? targetProfileId,
  }) {
    final url = Uri.parse('$baseUrl$path');
    return _sendJsonRequest(
      requiresAuth: requiresAuth,
      requestTargetProfileId: targetProfileId,
      isSuccess: (response) => response.statusCode == 200,
      send: (headers) => _httpClient
          .put(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10)),
    );
  }

  Future<dynamic> delete(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
    int? targetProfileId,
  }) {
    final url = Uri.parse('$baseUrl$path');
    return _sendJsonRequest(
      requiresAuth: requiresAuth,
      requestTargetProfileId: targetProfileId,
      isSuccess: (response) =>
          response.statusCode == 200 || response.statusCode == 204,
      send: (headers) => _httpClient
          .delete(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10)),
    );
  }

  Future<dynamic> _sendJsonRequest({
    required Future<http.Response> Function(Map<String, String> headers) send,
    required bool Function(http.Response response) isSuccess,
    required bool requiresAuth,
    required int? requestTargetProfileId,
    bool allowRetry = true,
  }) async {
    try {
      final headers = await _buildHeaders(
        requiresAuth: requiresAuth,
        requestTargetProfileId: requestTargetProfileId,
      );
      final response = await send(headers);

      // Phase 6: every response on the mobile risk surface carries
      // `X-Risk-Contract-Version`. Inspecting on success keeps the
      // singleton's `latestObserved` fresh for diagnostic logging.
      // Routes that are NOT on the risk surface simply omit the header
      // and the inspector returns silently.
      RiskContractVersion.instance.inspect(response.headers);

      if (isSuccess(response)) {
        if (response.body.isEmpty) {
          return <String, dynamic>{};
        }
        return _decodeResponseBody(response);
      }

      if (requiresAuth && response.statusCode == 401) {
        return _retryAuthorizedRequest(
          allowRetry: allowRetry,
          send: send,
          isSuccess: isSuccess,
          requestTargetProfileId: requestTargetProfileId,
        );
      }

      throw ApiRequestException(_extractServerErrorMessage(response));
    } catch (error) {
      throw _mapException(error);
    }
  }

  Future<dynamic> _retryAuthorizedRequest({
    required bool allowRetry,
    required Future<http.Response> Function(Map<String, String> headers) send,
    required bool Function(http.Response response) isSuccess,
    required int? requestTargetProfileId,
  }) async {
    const failureMessage =
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';

    if (!allowRetry) {
      await _sessionService.clearSession(message: failureMessage);
      throw const SessionExpiredException(failureMessage);
    }

    final refreshResult = await _sessionService.refreshSession(
      refreshTokenHandler: _refreshWithRawRequest,
      failureMessage: failureMessage,
    );
    if (!refreshResult.success) {
      throw SessionExpiredException(refreshResult.message ?? failureMessage);
    }

    return _sendJsonRequest(
      send: send,
      isSuccess: isSuccess,
      requiresAuth: true,
      requestTargetProfileId: requestTargetProfileId,
      allowRetry: false,
    );
  }

  Future<AuthResponse> _refreshWithRawRequest(String refreshToken) async {
    final url = Uri.parse('$baseUrl/auth/refresh');
    final response = await _httpClient
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decodedBody = _decodeResponseBody(response);
      if (decodedBody is Map) {
        return AuthResponse.fromJson(Map<String, dynamic>.from(decodedBody));
      }
    }

    return AuthResponse(
      success: false,
      message: _extractServerErrorMessage(response),
    );
  }

  dynamic _decodeResponseBody(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  Map<String, String> _normalizeQueryParams(Map<String, dynamic> queryParams) {
    final normalized = <String, String>{};
    queryParams.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is Iterable) {
        final values = value.map((item) => item.toString()).toList();
        if (values.isNotEmpty) {
          normalized[key] = values.join(',');
        }
        return;
      }
      normalized[key] = value.toString();
    });
    return normalized;
  }

  String _extractServerErrorMessage(http.Response response) {
    if (kDebugMode) {
      final method = response.request?.method ?? '?';
      final url = response.request?.url.toString() ?? '?';
      debugPrint('[ApiClient] $method $url → ${response.statusCode}');
      debugPrint('[ApiClient] response body: ${response.body}');
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }

        final detail = body['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }

        if (detail is List) {
          final validationMessages = detail
              .map((item) {
                if (item is Map<String, dynamic> && item['msg'] is String) {
                  return item['msg'] as String;
                }
                return item?.toString() ?? '';
              })
              .where((text) => text.trim().isNotEmpty)
              .toList();

          if (validationMessages.isNotEmpty) {
            return validationMessages.join('; ');
          }
        }
      }
    } catch (_) {
      // Fallback to status-based message below.
    }

    return _getErrorMessage(response.statusCode);
  }

  Exception _mapException(Object error) {
    if (error is SessionExpiredException) {
      return error;
    }

    if (error is ApiRequestException) {
      return Exception(error.message);
    }

    final raw = error.toString();
    final isNetworkError =
        error is TimeoutException ||
        error is http.ClientException ||
        raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection refused');

    if (isNetworkError) {
      return Exception('Network error: $raw');
    }

    return Exception(raw.replaceFirst('Exception: ', ''));
  }

  static String _getErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Yêu cầu không hợp lệ';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not found';
      case 429:
        return 'Quá nhiều requests. Vui lòng thử lại sau.';
      case 500:
        return 'Lỗi server';
      case 503:
        return 'Service unavailable';
      default:
        return 'Request failed (HTTP $statusCode)';
    }
  }
}
