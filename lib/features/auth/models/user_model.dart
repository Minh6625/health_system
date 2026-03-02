class UserModel {
  final String email;
  final String? fullName;
  final String password;

  UserModel({required this.email, this.fullName, required this.password});

  Map<String, dynamic> toJson() {
    return {'email': email, 'full_name': fullName ?? '', 'password': password};
  }
}
