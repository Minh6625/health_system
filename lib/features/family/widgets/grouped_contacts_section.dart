import 'package:flutter/material.dart';
import '../models/contact_tag.dart';
import '../models/linked_contact_model.dart';
import 'contacts_group_header.dart';
import 'linked_contact_card.dart';

class GroupedContactsSection extends StatelessWidget {
  final List<LinkedContactModel> contacts;

  const GroupedContactsSection({super.key, required this.contacts});

  @override
  Widget build(BuildContext context) {
    // Group theo custom tags (mỗi contact có thể có nhiều tag)
    // Dùng ContactTagsConfig.defaultTags làm thứ tự hiển thị
    final Map<String, List<LinkedContactModel>> tagGroups = {};

    // Khởi tạo tất cả default tag groups
    for (final tag in ContactTagsConfig.defaultTags) {
      tagGroups[tag.id] = <LinkedContactModel>[];
    }
    // Thêm nhóm "Chưa gắn tag"
    tagGroups['_untagged'] = <LinkedContactModel>[];

    for (final contact in contacts) {
      if (contact.tags.isEmpty) {
        tagGroups['_untagged']!.add(contact);
      } else {
        // Một contact có nhiều tag → xuất hiện ở nhiều group
        for (final tag in contact.tags) {
          tagGroups.putIfAbsent(tag.id, () => <LinkedContactModel>[]);
          tagGroups[tag.id]!.add(contact);
        }
      }
    }

    final List<Widget> children = [];

    // Hiển thị theo thứ tự: default tags trước, rồi custom, rồi untagged
    for (final tag in ContactTagsConfig.defaultTags) {
      final groupContacts = tagGroups[tag.id] ?? [];
      if (groupContacts.isNotEmpty) {
        children.add(ContactsGroupHeader(
          title: tag.name,
          color: tag.color,
        ));
        children.add(const SizedBox(height: 12));
        children.addAll(groupContacts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinkedContactCard(contact: c),
            )));
        children.add(const SizedBox(height: 8));
      }
    }

    // Section "Chưa gắn tag"
    final untagged = tagGroups['_untagged'] ?? [];
    if (untagged.isNotEmpty) {
      children.add(const ContactsGroupHeader(
        title: 'Chưa gắn tag',
        color: Color(0xFF9CA3AF),
      ));
      children.add(const SizedBox(height: 12));
      children.addAll(untagged.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LinkedContactCard(contact: c),
          )));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
