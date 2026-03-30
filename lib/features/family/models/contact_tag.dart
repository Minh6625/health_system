import 'package:flutter/material.dart';

/// Custom tag cho contact — thay thế enum role cứng
class ContactTag {
  final String id;
  final String name;
  final Color color;

  const ContactTag({required this.id, required this.name, required this.color});

  @override
  bool operator ==(Object other) => other is ContactTag && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tags mặc định gợi ý (default suggestions)
class ContactTagsConfig {
  static const List<ContactTag> defaultTags = [
    ContactTag(id: 'family', name: 'Gia đình', color: Color(0xFF2F80ED)),
    ContactTag(id: 'doctor', name: 'Bác sĩ', color: Color(0xFF2E9B6F)),
    ContactTag(id: 'friend', name: 'Bạn bè', color: Color(0xFFF2A93B)),
  ];

  static ContactTag? findById(String id) {
    try {
      return defaultTags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
