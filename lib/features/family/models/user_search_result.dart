class UserSearchResult {
  final int id;
  final String? fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;

  UserSearchResult({
    required this.id,
    this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
    );
  }
}
