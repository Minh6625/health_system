class UserSearchModel {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String connectionStatus; // 'none', 'pending', 'accepted'
  final int? relationshipId;
  final bool isIncoming;

  UserSearchModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.connectionStatus = 'none',
    this.relationshipId,
    this.isIncoming = false,
  });

  factory UserSearchModel.fromJson(Map<String, dynamic> json) {
    return UserSearchModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      connectionStatus: json['connection_status'] as String? ?? 'none',
      relationshipId: json['relationship_id'] as int?,
      isIncoming: json['is_incoming'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'connection_status': connectionStatus,
      'relationship_id': relationshipId,
      'is_incoming': isIncoming,
    };
  }
}
