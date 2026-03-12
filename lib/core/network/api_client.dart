import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:healthguard/features/auth/services/token_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class ApiClient {
  String get baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:8080/api/v1/mobile';

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  final TokenStorageService _tokenStorageService = TokenStorageService();

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) {
      final token = await _tokenStorageService.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Parse error message from response
        String errorMessage = 'Request failed';
        try {
          final errorBody = jsonDecode(response.body);
          // Try 'message' field (from custom response)
          errorMessage =
              errorBody['message'] as String? ??
              errorBody['detail']
                  as String? // FastAPI returns 'detail'
                  ??
              'Request failed';
        } catch (e) {
          // If JSON parse fails, use status code message
          errorMessage = _getErrorMessage(response.statusCode);
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> get(String path, {bool requiresAuth = true}) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Parse error message from response
        String errorMessage = 'Request failed';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage =
              errorBody['message'] as String? ??
              errorBody['detail'] as String? ??
              'Request failed';
        } catch (e) {
          errorMessage = _getErrorMessage(response.statusCode);
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .patch(
            url,
            headers: headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      String errorMessage = 'Request failed';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage =
            errorBody['message'] as String? ??
            errorBody['detail'] as String? ??
            'Request failed';
      } catch (e) {
        errorMessage = _getErrorMessage(response.statusCode);
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .put(
            url,
            headers: headers,
            body: jsonEncode(body ?? {}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      String errorMessage = 'Request failed';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage =
            errorBody['message'] as String? ??
            errorBody['detail'] as String? ??
            'Request failed';
      } catch (e) {
        errorMessage = _getErrorMessage(response.statusCode);
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await http
          .delete(url, headers: headers,
              body: body != null ? jsonEncode(body) : null)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isEmpty) {
          return <String, dynamic>{};
        }
        return jsonDecode(response.body);
      }

      String errorMessage = 'Request failed';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage =
            errorBody['message'] as String? ??
            errorBody['detail'] as String? ??
            'Request failed';
      } catch (e) {
        errorMessage = _getErrorMessage(response.statusCode);
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Network error: $e');
    }
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
