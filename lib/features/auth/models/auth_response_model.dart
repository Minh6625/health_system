class AuthResponse {
  final bool success;
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final UserData? user;

  AuthResponse({
    required this.success,
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      user: json['user'] != null ? UserData.fromJson(json['user']) : null,
    );
  }
}

class UserData {
  final int userId;
  final String email;
  final String fullName;
  final String role;

  UserData({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'role': role,
    };
  }
}
