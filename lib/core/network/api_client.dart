import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:healthguard/features/auth/services/token_storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiRequestException implements Exception {
  final String message;

  const ApiRequestException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  String get baseUrl {
    String url = dotenv.env['API_URL'] ?? 'http://10.0.2.2:8000/api/v1/mobile';
    if (kIsWeb) {
      url = url.replaceFirst('10.0.2.2', '127.0.0.1');
    }
    return url;
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  final TokenStorageService _tokenStorageService = TokenStorageService();

  int? targetProfileId;

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await _tokenStorageService.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    if (targetProfileId != null) {
      headers['X-Target-Profile-Id'] = targetProfileId.toString();
    }
    return headers;
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeResponseBody(response);
      }

      throw ApiRequestException(_extractServerErrorMessage(response));
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<dynamic> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      Uri url = Uri.parse('$baseUrl$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        url = url.replace(queryParameters: _normalizeQueryParams(queryParams));
      }
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _decodeResponseBody(response);
      }

      throw ApiRequestException(_extractServerErrorMessage(response));
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .patch(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _decodeResponseBody(response);
      }

      throw ApiRequestException(_extractServerErrorMessage(response));
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .put(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _decodeResponseBody(response);
      }

      throw ApiRequestException(_extractServerErrorMessage(response));
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<dynamic> delete(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .delete(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) {
          return <String, dynamic>{};
        }
        return _decodeResponseBody(response);
      }

      throw ApiRequestException(_extractServerErrorMessage(response));
    } catch (e) {
      throw _mapException(e);
    }
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

  // Helper method to get error message from status code
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
