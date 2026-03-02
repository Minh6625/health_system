import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  // Use 10.0.2.2 for Android emulator to access host machine's localhost
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal();

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
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

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
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
