import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  String get baseUrl => dotenv.env['API_URL'] ?? 'http://10.0.2.2:8080/api/v1/mobile';

  static final ApiClient _instance = ApiClient._internal();
  final _storage = const FlutterSecureStorage();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  /// Build headers with Authorization token if available
  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Get access token from secure storage
    final token = await _storage.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders();
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 5));

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

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _buildHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));

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
