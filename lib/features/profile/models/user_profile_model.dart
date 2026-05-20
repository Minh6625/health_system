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
  // Medical fields
  final String? gender;
  final String? bloodType;
  /// Backend stores `height_cm` in a Postgres `smallint` column; only
  /// whole-cm values are persistable, so the Dart side mirrors with `int`.
  final int? heightCm;
  final double? weightKg;
  final List<String> medications;
  final List<String> allergies;
  final List<String> medicalConditions;
  /// Phase 3: pinned primary device id. Null when the user has not
  /// chosen a primary source — the dashboard then falls back to the
  /// legacy "latest-of-all" query on the backend.
  final int? primaryDeviceId;
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
    this.gender,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.medications = const [],
    this.allergies = const [],
    this.medicalConditions = const [],
    this.primaryDeviceId,
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
      gender: json['gender'] as String?,
      bloodType: json['blood_type'] as String?,
      heightCm: (json['height_cm'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      medications: ((json['medications'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      allergies: ((json['allergies'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      medicalConditions: ((json['medical_conditions'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      primaryDeviceId: (json['primary_device_id'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
