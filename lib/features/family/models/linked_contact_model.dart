import 'package:healthguard/features/family/models/contact_tag.dart';

class LinkedContactModel {
  final String id;
  final String displayName;
  final String email;
  final String avatarUrl;
  /// Nhãn hiển thị chính (có thể do user tự đặt hoặc fallback từ tag đầu tiên)
  final String primaryRelationshipLabel;
  /// Custom tags — thay thế enum role cứng là source of truth chính
  final List<ContactTag> tags;
  /// Giữ role enum làm fallback / suggestion — không dùng làm grouping chính
  final ContactRole role;
  final ContactStatus status;
  /// Permissions: 'can_view_vitals', 'can_receive_alerts', 'can_view_location'
  final List<String> permissions;
  final bool isIncomingRequest;

  LinkedContactModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl = '',
    String? primaryRelationshipLabel,
    List<ContactTag>? tags,
    this.role = ContactRole.unclassified,
    this.status = ContactStatus.accepted,
    this.permissions = const [],
    this.isIncomingRequest = false,
  })  : tags = tags ?? const [],
        primaryRelationshipLabel = primaryRelationshipLabel ??
            (tags != null && tags.isNotEmpty ? tags.first.name : role.label);

  LinkedContactModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    String? primaryRelationshipLabel,
    List<ContactTag>? tags,
    ContactRole? role,
    ContactStatus? status,
    List<String>? permissions,
    bool? isIncomingRequest,
  }) {
    return LinkedContactModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      primaryRelationshipLabel: primaryRelationshipLabel ?? this.primaryRelationshipLabel,
      tags: tags ?? this.tags,
      role: role ?? this.role,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      isIncomingRequest: isIncomingRequest ?? this.isIncomingRequest,
    );
  }
}

enum ContactStatus {
  pending,
  accepted,
  rejected,
}

/// Enum role giữ lại làm suggestion defaults, không phải source of truth chính
enum ContactRole {
  family('Gia đình'),
  doctor('Bác sĩ'),
  friend('Bạn bè'),
  unclassified('Chưa phân loại');

  final String label;
  const ContactRole(this.label);
}
