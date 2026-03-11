class UserProfileModel {
  final int userId;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final DateTime? dateOfBirth;
  final bool isActive;
  final bool isVerified;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfileModel({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.dateOfBirth,
    required this.isActive,
    required this.isVerified,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: (json['user_id'] as num).toInt(),
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
