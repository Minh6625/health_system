class AccessProfile {
  final int id;
  final String fullName;
  final String? avatarUrl;
  final String relationshipType;
  final bool canViewVitals;
  final bool canReceiveAlerts;
  final bool canViewLocation;

  AccessProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.relationshipType,
    this.canViewVitals = true,
    this.canReceiveAlerts = true,
    this.canViewLocation = true,
  });

  factory AccessProfile.fromJson(Map<String, dynamic> json) {
    return AccessProfile(
      id: json['id'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      relationshipType: json['relationship_type'],
      canViewVitals: json['can_view_vitals'] ?? true,
      canReceiveAlerts: json['can_receive_alerts'] ?? true,
      canViewLocation: json['can_view_location'] ?? true,
    );
  }
}
