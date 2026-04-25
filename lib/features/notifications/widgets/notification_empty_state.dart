import 'package:flutter/material.dart';

import 'notification_filter_chips.dart';

/// Empty placeholder for the notifications list. Wording adapts to whether
/// the user is searching or simply on an empty filter.
class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({
    super.key,
    required this.isSearching,
    required this.filter,
  });

  final bool isSearching;
  final NotificationFilter filter;

  String _resolveMessage() {
    if (isSearching) {
      return 'Không tìm thấy thông báo phù hợp';
    }
    switch (filter) {
      case NotificationFilter.read:
        return 'Chưa có thông báo đã đọc';
      case NotificationFilter.unread:
        return 'Không có thông báo chưa đọc';
      case NotificationFilter.all:
        return 'Chưa có thông báo nào';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(child: Text(_resolveMessage())),
      ],
    );
  }
}
