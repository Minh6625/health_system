class UserModel {
  final String email;
  final String? fullName;
  final String password;
  final String role;  // user | admin
  final DateTime? dateOfBirth;  // YYYY-MM-DD
  final String? phone;  // 10-11 digits

  UserModel({
    required this.email,
    this.fullName,
    required this.password,
    this.role = 'user',
    this.dateOfBirth,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'full_name': fullName ?? '',
      'password': password,
      'role': role,
      'date_of_birth': dateOfBirth != null ? dateOfBirth!.toIso8601String().split('T')[0] : null,
      'phone': phone,
    };
  }
}
