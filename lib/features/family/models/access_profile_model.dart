class AccessProfileModel {
  const AccessProfileModel({
    required this.id,
    required this.fullName,
    required this.relationshipType,
    required this.canViewVitals,
    required this.canReceiveAlerts,
    required this.canViewLocation,
    this.avatarUrl,
  });

  final int id;
  final String fullName;
  final String relationshipType;
  final bool canViewVitals;
  final bool canReceiveAlerts;
  final bool canViewLocation;
  final String? avatarUrl;

  factory AccessProfileModel.fromJson(Map<String, dynamic> json) {
    return AccessProfileModel(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      relationshipType: json['relationship_type'] as String? ?? 'family',
      canViewVitals: json['can_view_vitals'] as bool? ?? false,
      canReceiveAlerts: json['can_receive_alerts'] as bool? ?? false,
      canViewLocation: json['can_view_location'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
